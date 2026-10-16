import * as admin from "firebase-admin";
import { randomUUID } from "crypto";
import axios from "axios";
import carrierDirectory from "./carrierDirectory.json";
import { defineSecret } from "firebase-functions/params";
import {
  onDocumentCreated,
  onDocumentWritten,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { onRequest, onCall, HttpsError } from "firebase-functions/v2/https";

import { TEMPLATES, REGION, WA_COLLECTION } from "./config";
import { LoadRecord, OfferRecord, UserRecord, WaStatus } from "./types";
import {
  findMatchingCarriers,
  findAdmins,
  findUserByUuid,
  formatPhone,
  formatPrice,
} from "./carriers";
import {
  getMailTransport,
  buildLoadMailOptions,
  buildAdminLoadPublishedOptions,
  buildAssignedMailOptions,
  buildOfferMailOptions,
  buildStatusMailOptions,
  buildInvitationMailOptions,
  buildCounterOfferAdminMailOptions,
  buildCounterOfferApprovedMailOptions,
  buildCounterOfferRejectedMailOptions,
} from "./email";
import {
  sendWhatsAppTemplate,
  validateWebhookSignature,
  updateWaStatusByWamid,
  textParams,
} from "./whatsapp";
import { handleIncomingMessage, IncomingMsg } from "./messageHandler";
import { initClaudeAI } from "./aiResponse";
import { initConversationsAI } from "./conversations";

// ─── Initialize ───────────────────────────────────────────────────────────────

admin.initializeApp();

// ─── Secrets (resolved at runtime, never in source code) ─────────────────────

const waToken         = defineSecret("WHATSAPP_ACCESS_TOKEN");
const waPhoneId       = defineSecret("WHATSAPP_PHONE_NUMBER_ID");
const waWebhookSecret = defineSecret("WHATSAPP_WEBHOOK_SECRET"); // verify token (GET challenge)
const waAppSecret     = defineSecret("WHATSAPP_APP_SECRET");     // app secret (POST HMAC)
const gmailUser       = defineSecret("GMAIL_USER");
const gmailPass       = defineSecret("GMAIL_PASS");
const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

// All secrets that touch WhatsApp
const WA_SECRETS  = [waToken, waPhoneId, gmailUser, gmailPass] as const;
// Webhook needs verify token + app secret + AI key
const WH_SECRETS  = [waWebhookSecret, waAppSecret, anthropicApiKey] as const;

// ─── Twilio secrets (AI calls — configure before deploying onLoadUrgencyCallAlert)
const twilioSid   = defineSecret("TWILIO_ACCOUNT_SID");
const twilioToken = defineSecret("TWILIO_AUTH_TOKEN");
const twilioFrom  = defineSecret("TWILIO_FROM_NUMBER");

// ─── ElevenLabs integration secrets ──────────────────────────────────────────
// Set via:
//   firebase functions:secrets:set ELEVENLABS_SECRET
//   printf "<uuid>" | firebase functions:secrets:set ELEVENLABS_AUTHORIZED_PUBLISHER
// Use printf (not echo) to avoid trailing newlines in stored values.
const elevenLabsSecret    = defineSecret("ELEVENLABS_SECRET");
const elevenLabsPublisher = defineSecret("ELEVENLABS_AUTHORIZED_PUBLISHER");

// ─── Route formatting helper ──────────────────────────────────────────────────

/** "Ciudad, Estado" when city is present, "Estado" otherwise */
function fmtPlace(city: string | undefined, state: string): string {
  const c = city?.trim();
  if (!c) return state;
  const norm = (s: string) => s.toLowerCase().replace(/[^a-z0-9]/g, "");
  return norm(c) === norm(state) ? state : `${c}, ${state}`;
}

/** "DD/MM/AAAA a las H am/pm" for email pickup date display */
function fmtPickupDate(ts: admin.firestore.Timestamp | undefined): string | undefined {
  if (!ts) return undefined;
  const d = ts.toDate();
  const day  = d.toLocaleDateString("es-MX", { day: "2-digit", month: "2-digit", year: "numeric" });
  const hour = d.getHours();
  const min  = d.getMinutes();
  const hhmm = min === 0
    ? `${hour === 12 ? 12 : hour % 12} ${hour < 12 ? "am" : "pm"}`
    : `${hour === 12 ? 12 : hour % 12}:${String(min).padStart(2, "0")} ${hour < 12 ? "am" : "pm"}`;
  return `${day} a las ${hhmm}`;
}

// ─── Shared sender helper ─────────────────────────────────────────────────────

interface SendContext {
  phoneNumberId: string;
  accessToken: string;
  mailer: ReturnType<typeof getMailTransport>;
  fromEmail: string;
}

function buildContext(): SendContext {
  return {
    phoneNumberId: waPhoneId.value(),
    accessToken:   waToken.value(),
    mailer:        getMailTransport(gmailUser.value(), gmailPass.value()),
    fromEmail:     `"Continente Conecta" <${gmailUser.value()}>`,
  };
}

// ─── Helper: mark user whatsappOptOut if number not on WhatsApp ───────────────

async function markNoWhatsAppIfNeeded(
  idempotencyKey: string,
  userUuid: string
): Promise<void> {
  try {
    const waDoc = await admin.firestore()
      .collection(WA_COLLECTION).doc(idempotencyKey).get();
    const errStr: string = waDoc.data()?.error ?? "";
    if (!errStr.includes("131026")) return;
    // User documents use Firebase Auth UID as the doc ID, not the app UUID.
    const userSnap = await admin.firestore()
      .collection("users")
      .where("uuid", "==", userUuid)
      .limit(1)
      .get();
    if (userSnap.empty) return;
    await userSnap.docs[0].ref.update({ whatsappOptOut: true });
    console.log(`[WA] Marked uuid=${userUuid} whatsappOptOut=true (error 131026)`);
  } catch (e) {
    console.error(`[WA] markNoWhatsAppIfNeeded failed for uuid=${userUuid}:`, e);
  }
}

// ─── 1. onLoadPublished ───────────────────────────────────────────────────────
// Fires when a load document transitions to status "Publicado".
// Notifies every approved carrier whose routes match the load's route+equipment.

export const onLoadPublished = onDocumentWritten(
  { document: "loads/{loadId}", region: REGION, secrets: [...WA_SECRETS] },
  async (event) => {
    const before = event.data?.before.data() as LoadRecord | undefined;
    const after  = event.data?.after.data()  as LoadRecord | undefined;
    if (!after || after.status !== "Publicado") return;
    if (before?.status === "Publicado") return; // already handled

    const loadId  = event.params.loadId;
    const ctx     = buildContext();
    const carriers = await findMatchingCarriers(
      after.originState, after.destinationState, after.equipmentType
    );

    const priceStr = formatPrice(after.offeredPrice);

    // Look up the admin who published this load to send them a confirmation email.
    const publisherUuid = typeof after.publishedBy === "string" ? after.publishedBy : "";
    const publisher = publisherUuid ? await findUserByUuid(publisherUuid) : null;

    if (carriers.length === 0) {
      console.log(`[Load] No carriers for ${after.originState}→${after.destinationState}`);
      // Still send admin confirmation even when no carriers matched.
      if (publisher?.email) {
        try {
          await ctx.mailer.sendMail(
            buildAdminLoadPublishedOptions(
              publisher.email, after.reference,
              fmtPlace(after.originCity, after.originState),
              fmtPlace(after.destinationCity, after.destinationState),
              after.equipmentType, priceStr, after.currency,
              0, ctx.fromEmail
            )
          );
          console.log(`[Email] ✅ Admin publish confirmation sent to ${publisher.email} (0 carriers)`);
        } catch (e) {
          console.error(`[Email] Admin publish confirmation failed:`, e);
        }
      }
      return;
    }
    console.log(`[Load] Notifying ${carriers.length} carriers for ${after.reference}`);

    await Promise.allSettled(carriers.map(async (carrier) => {
      const firstName = carrier.name.split(" ")[0];
      const phone     = formatPhone(carrier.phone ?? "");
      const uuid      = carrier.uuid ?? carrier.email; // fallback key

      console.log(`[LP-DBG] carrier="${carrier.name}" rawPhone="${carrier.phone ?? ""}" formatted="${phone ?? "null"}"`);

      // WhatsApp (skip if opted out OR channel disabled)
      if (phone && carrier.whatsappOptOut !== true && (after.notificationChannels?.whatsapp !== false)) {
        console.log(`[LP-DBG2] About to call sendWhatsAppTemplate for ${carrier.name}`);
        try {
          const sent = await sendWhatsAppTemplate({
            phoneNumberId: ctx.phoneNumberId,
            accessToken:   ctx.accessToken,
            to:            phone,
            templateName:  TEMPLATES.newLoad,
            bodyParams:    textParams(
              firstName,
              after.reference,
              fmtPlace(after.originCity, after.originState),
              fmtPlace(after.destinationCity, after.destinationState),
            ),
            quickReplyButtons: [
              { index: 0, payload: "INTERESTED" },
              { index: 1, payload: "NOT_INTERESTED" },
            ],
            idempotencyKey: `lp:${loadId}:${uuid}`,
            event:          "load_published",
            loadId,
            carrierId:      uuid,
          });
          console.log(`[LP-DBG2] sendWhatsAppTemplate returned: ${sent}`);
          if (!sent) await markNoWhatsAppIfNeeded(`lp:${loadId}:${uuid}`, uuid);
        } catch (waErr) {
          console.error(`[LP-DBG2] sendWhatsAppTemplate THREW for ${carrier.name}:`, waErr);
        }
      } else if (!phone) {
        console.log(`[LP-DBG2] Skipping WA for ${carrier.name} — phone is null`);
      }

      // Email to carrier
      if (after.notificationChannels?.email !== false) {
        try {
          await ctx.mailer.sendMail(
            buildLoadMailOptions(
              { firstName, reference: after.reference,
                origin: fmtPlace(after.originCity, after.originState),
                destination: fmtPlace(after.destinationCity, after.destinationState),
                equipment: after.equipmentType,
                unitCount: after.unitCount, priceStr, currency: after.currency,
                assignmentMode: after.assignmentMode, isUrgent: false,
                pickupDateStr: fmtPickupDate(after.pickupDate) },
              carrier.email, ctx.fromEmail
            )
          );
          console.log(`[Email] ✅ Load notification sent to ${carrier.email}`);
        } catch (e) {
          console.error(`[Email] Load notification failed for ${carrier.email}:`, e);
        }
      }
    }));

    // Confirmation email to the admin who published the load.
    if (publisher?.email) {
      try {
        await ctx.mailer.sendMail(
          buildAdminLoadPublishedOptions(
            publisher.email, after.reference,
            fmtPlace(after.originCity, after.originState),
            fmtPlace(after.destinationCity, after.destinationState),
            after.equipmentType, priceStr, after.currency,
            carriers.length, ctx.fromEmail
          )
        );
        console.log(`[Email] ✅ Admin publish confirmation sent to ${publisher.email} (${carriers.length} carriers)`);
      } catch (e) {
        console.error(`[Email] Admin publish confirmation failed:`, e);
      }
    }
  }
);

// ─── 2. onLoadUrgencyAlert ────────────────────────────────────────────────────
// Fires when the admin sets urgentRepost = true on a load.

export const onLoadUrgencyAlert = onDocumentWritten(
  { document: "loads/{loadId}", region: REGION, secrets: [...WA_SECRETS] },
  async (event) => {
    const before = event.data?.before.data() as LoadRecord | undefined;
    const after  = event.data?.after.data()  as LoadRecord | undefined;
    if (!after?.urgentRepost)       return;
    if (before?.urgentRepost === true) return; // debounce

    // Clear the flag immediately to prevent re-processing on retries
    await event.data!.after.ref.update({ urgentRepost: false });

    const loadId   = event.params.loadId;
    const ctx      = buildContext();
    const carriers = await findMatchingCarriers(
      after.originState, after.destinationState, after.equipmentType
    );
    if (carriers.length === 0) return;

    const priceStr = formatPrice(after.offeredPrice);
    // Use a per-minute bucket so each urgency alert can reach carriers again
    const minuteBucket = Math.floor(Date.now() / 60_000);

    await Promise.allSettled(carriers.map(async (carrier) => {
      const firstName = carrier.name.split(" ")[0];
      const phone     = formatPhone(carrier.phone);
      const uuid      = carrier.uuid ?? carrier.email;

      if (phone && (after.notificationChannels?.whatsapp !== false)) {
        const sent = await sendWhatsAppTemplate({
          phoneNumberId: ctx.phoneNumberId,
          accessToken:   ctx.accessToken,
          to:            phone,
          templateName:  TEMPLATES.urgentLoad,
          bodyParams:    textParams(
            firstName, after.reference,
            fmtPlace(after.originCity, after.originState),
            fmtPlace(after.destinationCity, after.destinationState),
          ),
          idempotencyKey: `lu:${loadId}:${uuid}:${minuteBucket}`,
          event:          "load_urgency",
          loadId, carrierId: uuid,
        });
        if (!sent) await markNoWhatsAppIfNeeded(`lu:${loadId}:${uuid}:${minuteBucket}`, uuid);
      }

      if (after.notificationChannels?.email !== false) {
        try {
          await ctx.mailer.sendMail(
            buildLoadMailOptions(
              { firstName, reference: after.reference,
                origin: fmtPlace(after.originCity, after.originState),
                destination: fmtPlace(after.destinationCity, after.destinationState),
                equipment: after.equipmentType,
                unitCount: after.unitCount, priceStr, currency: after.currency,
                assignmentMode: after.assignmentMode, isUrgent: true,
                pickupDateStr: fmtPickupDate(after.pickupDate) },
              carrier.email, ctx.fromEmail
            )
          );
        } catch (e) {
          console.error(`[Email] Urgency failed for ${carrier.email}:`, e);
        }
      }
    }));
  }
);

// ─── 3. onLoadAssigned ────────────────────────────────────────────────────────
// Fires when a load's status changes to "Asignado".

export const onLoadAssigned = onDocumentUpdated(
  { document: "loads/{loadId}", region: REGION, secrets: [...WA_SECRETS] },
  async (event) => {
    if (!event.data) return;
    const before = event.data.before.data() as LoadRecord;
    const after  = event.data.after.data()  as LoadRecord;
    if (before.status === after.status || after.status !== "Asignado") return;

    const carrierId = after.assignedCarrierId;
    if (!carrierId) return;

    const carrier = await findUserByUuid(carrierId);
    if (!carrier) {
      console.warn(`[Load] Assigned carrier not found: ${carrierId}`);
      return;
    }

    const loadId    = event.params.loadId;
    const ctx       = buildContext();
    const firstName = carrier.name.split(" ")[0];
    const phone     = formatPhone(carrier.phone);

    // Skip WhatsApp template if assigned via WhatsApp bot — bot already sent confirmation.
    const assignedViaWhatsApp = (after as LoadRecord & { assignedVia?: string }).assignedVia === "whatsapp";
    if (phone && !assignedViaWhatsApp) {
      await sendWhatsAppTemplate({
        phoneNumberId: ctx.phoneNumberId,
        accessToken:   ctx.accessToken,
        to:            phone,
        templateName:  TEMPLATES.loadAssigned,
        bodyParams:    textParams(
          firstName, after.reference,
          fmtPlace(after.originCity, after.originState),
          fmtPlace(after.destinationCity, after.destinationState),
        ),
        idempotencyKey: `la:${loadId}:${carrierId}`,
        event:          "load_assigned",
        loadId, carrierId,
      });
    }

    const emailNotifId = `la:${loadId}:${carrierId}`;
    const emailNotifRef = admin.firestore().collection("email_notifications").doc(emailNotifId);
    try {
      await ctx.mailer.sendMail(
        buildAssignedMailOptions(
          firstName,
          after.reference,
          after.originState,
          after.destinationState,
          typeof after.assignedPriceSinIVA === "number" ? after.assignedPriceSinIVA : null,
          after.currency,
          carrier.email,
          ctx.fromEmail,
        )
      );
      await emailNotifRef.set({
        loadId, carrierId, to: carrier.email,
        status: "sent", sentAt: admin.firestore.Timestamp.now(),
        attempts: 1, updatedAt: admin.firestore.Timestamp.now(),
      });
    } catch (e) {
      console.error(`[Email] Assigned notification failed:`, e);
      await emailNotifRef.set({
        loadId, carrierId, to: carrier.email,
        status: "failed", error: String(e),
        attempts: 1, updatedAt: admin.firestore.Timestamp.now(),
      });
    }
  }
);

// ─── 4. onOfferCreated ────────────────────────────────────────────────────────
// Fires when a carrier submits an offer on a load.
// Notifies all admins.

export const onOfferCreated = onDocumentCreated(
  { document: "offers/{offerId}", region: REGION, secrets: [...WA_SECRETS] },
  async (event) => {
    const offer = event.data?.data() as OfferRecord | undefined;
    if (!offer) return;
    if (offer.isAvailabilityOnly) return; // not a real bid

    const offerId  = event.params.offerId;
    const ctx      = buildContext();
    const admins   = await findAdmins();

    // Look up the load for its reference and published price
    const loadSnap = await admin.firestore().collection("loads").doc(offer.loadId).get();
    const loadData = loadSnap.data();
    const loadRef  = (loadData?.reference as string) ?? offer.loadId;

    const isPendingApproval = offer.status === "PendienteAprobacion";
    // Direct assignments (Ganadora) are already notified via the load-update trigger — skip here
    if (offer.status === "Ganadora") return;

    if (isPendingApproval) {
      // Counter-offer: carrier proposed a price that needs admin approval
      const proposedStr  = formatPrice(offer.proposedPrice ?? offer.amount);
      const publishedStr = loadData ? formatPrice(loadData.offeredPrice as number / (loadData.unitCount as number || 1)) : "—";
      const unitCount    = offer.availableUnitCount ?? 1;

      await Promise.allSettled(admins.map(async (adm) => {
        const firstName = adm.name.split(" ")[0];
        const phone     = formatPhone(adm.phone);
        const uuid      = adm.uuid ?? adm.email;

        if (phone) {
          await sendWhatsAppTemplate({
            phoneNumberId: ctx.phoneNumberId,
            accessToken:   ctx.accessToken,
            to:            phone,
            templateName:  TEMPLATES.offerReceived,
            bodyParams:    textParams(
              firstName, offer.carrierName, loadRef,
              `${proposedStr} (contra-oferta pendiente)`
            ),
            idempotencyKey: `co:${offerId}:${uuid}`,
            event:          "counter_offer_received",
            offerId, carrierId: offer.carrierId, adminId: uuid,
          });
        }

        try {
          await ctx.mailer.sendMail(
            buildCounterOfferAdminMailOptions(
              firstName, offer.carrierName, loadRef,
              proposedStr, publishedStr, offer.currency,
              unitCount, adm.email, ctx.fromEmail
            )
          );
          console.log(`[Email] ✅ Counter-offer admin alert sent to ${adm.email}`);
        } catch (e) {
          console.error(`[Email] Counter-offer admin alert failed for ${adm.email}:`, e);
        }
      }));
      return;
    }

    // Regular offer (auction / availability)
    const amountStr = formatPrice(offer.amount);
    await Promise.allSettled(admins.map(async (adm) => {
      const firstName = adm.name.split(" ")[0];
      const phone     = formatPhone(adm.phone);
      const uuid      = adm.uuid ?? adm.email;

      if (phone) {
        await sendWhatsAppTemplate({
          phoneNumberId: ctx.phoneNumberId,
          accessToken:   ctx.accessToken,
          to:            phone,
          templateName:  TEMPLATES.offerReceived,
          bodyParams:    textParams(
            firstName, offer.carrierName, loadRef, amountStr
          ),
          idempotencyKey: `or:${offerId}:${uuid}`,
          event:          "offer_received",
          offerId, carrierId: offer.carrierId, adminId: uuid,
        });
      }

      try {
        await ctx.mailer.sendMail(
          buildOfferMailOptions(
            firstName, offer.carrierName, loadRef, amountStr, offer.currency,
            adm.email, ctx.fromEmail
          )
        );
      } catch (e) {
        console.error(`[Email] Offer notification failed for ${adm.email}:`, e);
      }
    }));
  }
);

// ─── 4b. onCounterOfferApproved ──────────────────────────────────────────────
// Fires when admin approves or rejects a counter-offer (PendienteAprobacion → Ganadora / Rechazada).
// Notifies the carrier via email + WhatsApp on approval; email-only on rejection.

export const onCounterOfferApproved = onDocumentUpdated(
  { document: "offers/{offerId}", region: REGION, secrets: [...WA_SECRETS] },
  async (event) => {
    if (!event.data) return;
    const before = event.data.before.data() as OfferRecord;
    const after  = event.data.after.data()  as OfferRecord;

    if (before.status !== "PendienteAprobacion") return;
    const isApproved = after.status === "Ganadora";
    const isRejected = after.status === "Rechazada";
    if (!isApproved && !isRejected) return;

    const offerId = event.params.offerId;
    const ctx     = buildContext();

    const carrier = await findUserByUuid(after.carrierId);
    if (!carrier) {
      console.warn(`[CounterOffer] Carrier not found: ${after.carrierId}`);
      return;
    }

    const loadSnap = await admin.firestore().collection("loads").doc(after.loadId).get();
    const loadRef  = (loadSnap.data()?.reference as string) ?? after.loadId;
    const firstName = carrier.name.split(" ")[0];
    const phone     = formatPhone(carrier.phone);
    const proposedStr = formatPrice(after.proposedPrice ?? after.amount);

    if (isApproved) {
      if (phone) {
        await sendWhatsAppTemplate({
          phoneNumberId: ctx.phoneNumberId,
          accessToken:   ctx.accessToken,
          to:            phone,
          templateName:  TEMPLATES.loadAssigned,
          bodyParams:    textParams(
            firstName, loadRef,
            loadSnap.data()?.originState ?? "",
            loadSnap.data()?.destinationState ?? "",
          ),
          idempotencyKey: `coa:${offerId}:${after.carrierId}`,
          event:          "counter_offer_approved",
          offerId, carrierId: after.carrierId,
        });
      }

      try {
        await ctx.mailer.sendMail(
          buildCounterOfferApprovedMailOptions(
            firstName, loadRef, proposedStr, after.currency, carrier.email, ctx.fromEmail
          )
        );
        console.log(`[Email] ✅ Counter-offer approved sent to ${carrier.email}`);
      } catch (e) {
        console.error(`[Email] Counter-offer approved email failed:`, e);
      }
    } else {
      // Rejected
      try {
        await ctx.mailer.sendMail(
          buildCounterOfferRejectedMailOptions(
            firstName, loadRef, carrier.email, ctx.fromEmail
          )
        );
        console.log(`[Email] ✅ Counter-offer rejected sent to ${carrier.email}`);
      } catch (e) {
        console.error(`[Email] Counter-offer rejected email failed:`, e);
      }
    }
  }
);

// ─── 5. onUserRegistered ─────────────────────────────────────────────────────
// Fires when a carrier document is first created in Firestore.

export const onUserRegistered = onDocumentCreated(
  { document: "users/{uid}", region: REGION, secrets: [...WA_SECRETS] },
  async (event) => {
    const user = event.data?.data() as UserRecord | undefined;
    if (!user || user.role === "admin") return;

    const userId    = event.params.uid;
    const ctx       = buildContext();
    const firstName = user.name.split(" ")[0];
    const phone     = formatPhone(user.phone);

    if (phone) {
      const sent = await sendWhatsAppTemplate({
        phoneNumberId: ctx.phoneNumberId,
        accessToken:   ctx.accessToken,
        to:            phone,
        templateName:  TEMPLATES.userRegistered,
        bodyParams:    textParams(firstName),
        idempotencyKey: `ur:${userId}`,
        event:          "user_registered",
        carrierId:      userId,
      });

      // If Meta returned error 131026, the number is not registered on WhatsApp.
      // Mark the user so future notifications are skipped.
      if (!sent) {
        const waDoc = await admin.firestore()
          .collection(WA_COLLECTION).doc(`ur:${userId}`).get();
        const errStr: string = waDoc.data()?.error ?? "";
        if (errStr.includes("131026")) {
          await admin.firestore()
            .collection("users").doc(userId)
            .update({ whatsappOptOut: true });
          console.log(`[User] ${userId} has no WhatsApp — marked whatsappOptOut=true`);
        }
      }
    }

    // No email on registration — Firebase Auth sends its own verification email.
  }
);

// ─── 6. onUserStatusChanged ───────────────────────────────────────────────────
// Fires when a carrier's status changes to "approved" or "rejected".

export const onUserStatusChanged = onDocumentUpdated(
  { document: "users/{uid}", region: REGION, secrets: [...WA_SECRETS] },
  async (event) => {
    if (!event.data) return;
    const before = event.data.before.data() as UserRecord;
    const after  = event.data.after.data()  as UserRecord;

    console.log(`[Status] uid=${event.params.uid} before=${before.status} after=${after.status} role=${after.role}`);

    if (before.status === after.status || after.role === "admin") return;

    const isApproved = after.status === "approved";
    const isRejected = after.status === "rejected";
    if (!isApproved && !isRejected) return;

    const userId    = event.params.uid;
    const ctx       = buildContext();
    const firstName = after.name.split(" ")[0];
    const phone     = formatPhone(after.phone);
    const template  = isApproved ? TEMPLATES.userApproved : TEMPLATES.userRejected;
    const eventType = isApproved ? "user_approved" : "user_rejected";

    console.log(`[Status] Sending ${eventType} to ${after.email} phone=${phone ?? "null"}`);

    if (phone) {
      await sendWhatsAppTemplate({
        phoneNumberId: ctx.phoneNumberId,
        accessToken:   ctx.accessToken,
        to:            phone,
        templateName:  template,
        bodyParams:    textParams(firstName),
        idempotencyKey: `${eventType}:${userId}`,
        event:          eventType as "user_approved" | "user_rejected",
        carrierId:      userId,
      });
    }

    try {
      await ctx.mailer.sendMail(
        buildStatusMailOptions(firstName, after.email, isApproved, ctx.fromEmail)
      );
      console.log(`[Email] ✅ Status email sent to ${after.email}`);
    } catch (e) {
      console.error(`[Email] ❌ Status notification failed for ${after.email}:`, e);
    }
  }
);

// ─── 9. onLoadUrgencyCallAlert ────────────────────────────────────────────────
// Fires when urgentRepost=true AND notificationChannels.aiCall=true.
// Makes outbound AI voice calls to matching carriers via Twilio.
// Deploy only after setting secrets:
//   firebase functions:secrets:set TWILIO_ACCOUNT_SID
//   firebase functions:secrets:set TWILIO_AUTH_TOKEN
//   firebase functions:secrets:set TWILIO_FROM_NUMBER

export const onLoadUrgencyCallAlert = onDocumentWritten(
  { document: "loads/{loadId}", region: REGION,
    secrets: [twilioSid, twilioToken, twilioFrom] },
  async (event) => {
    const before = event.data?.before.data() as LoadRecord | undefined;
    const after  = event.data?.after.data()  as LoadRecord | undefined;
    if (!after?.urgentRepost)          return;
    if (before?.urgentRepost === true) return;
    if (!after.notificationChannels?.aiCall) return;

    const loadId   = event.params.loadId;
    const carriers = await findMatchingCarriers(
      after.originState, after.destinationState, after.equipmentType
    );
    if (carriers.length === 0) return;

    await Promise.allSettled(carriers.map(async (carrier) => {
      const firstName = carrier.name.split(" ")[0];
      const phone     = formatPhone(carrier.phone);
      if (!phone) return;

      const message =
        `Hola ${firstName}, te habla Continente Conecta. ` +
        `Tenemos una carga urgente de ${after.originState} a ${after.destinationState} ` +
        `que requiere atención inmediata. ` +
        `Ingresa a la plataforma para ver los detalles y participar. ` +
        `Gracias.`;

      try {
        await makeTwilioCall({
          accountSid: twilioSid.value(),
          authToken:  twilioToken.value(),
          from:       twilioFrom.value(),
          to:         phone,
          message,
        });
        console.log(`[Twilio] Call initiated to ${carrier.name} (${phone}) — load ${loadId}`);
      } catch (err: unknown) {
        const detail = (err as { response?: { data?: unknown }; message?: string })
          .response?.data ?? (err as Error).message;
        console.error(`[Twilio] Call failed for ${carrier.name}:`, detail);
      }
    }));
  }
);

async function makeTwilioCall(opts: {
  accountSid: string; authToken: string;
  from: string; to: string; message: string;
}): Promise<void> {
  const { accountSid, authToken, from, to, message } = opts;
  const twiml =
    `<Response><Pause length="1"/>` +
    `<Say language="es-MX" voice="alice">${message}</Say></Response>`;
  const body = new URLSearchParams({ To: to, From: from, Twiml: twiml }).toString();
  await axios.post(
    `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Calls.json`,
    body,
    {
      auth: { username: accountSid, password: authToken },
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
    }
  );
}

// ─── 8. onInvitationCreated ───────────────────────────────────────────────────
// Fires when an admin writes a new invitation document.
// Sends cc_invitacion WhatsApp template to the invitee.

function registrationPhone(phone: string | undefined): string {
  const digits = (phone || "").replace(/\D/g, "");
  if (digits.startsWith("52") && digits.length === 12) return digits.slice(2);
  return /^\d{10}$/.test(digits) ? digits : "";
}

function registrationLink(phone: string | undefined): string {
  const base = (process.env.REGISTRATION_BASE_URL || "https://continente-conecta.web.app").replace(/\/$/, "");
  const suffix = registrationPhone(phone);
  return suffix ? `${base}/register?telefono=${suffix}` : `${base}/register`;
}

export const onInvitationCreated = onDocumentCreated(
  { document: "invitations/{inviteId}", region: REGION, secrets: [...WA_SECRETS] },
  async (event) => {
    const data = event.data?.data() as {
      name: string; phone: string; email?: string; channel?: string;
    } | undefined;
    if (!data) return;

    const { name, phone, email, channel = "whatsapp" } = data;
    const ctx       = buildContext();
    const firstName = name.split(" ")[0];
    const inviteId  = event.params.inviteId;
    const link      = registrationLink(phone);

    // ── Email channel ─────────────────────────────────────────────────────────
    if (channel === "email") {
      if (!email) {
        await event.data!.ref.update({ status: "invalid_email" });
        return;
      }
      try {
        const mailOptions = buildInvitationMailOptions(
          firstName,
          email,
          ctx.fromEmail,
          phone || undefined,
          link
        );
        await ctx.mailer.sendMail(mailOptions);
        await event.data!.ref.update({
          status: "sent",
          sentAt: admin.firestore.Timestamp.now(),
        });
      } catch (err) {
        console.error("[onInvitationCreated] Email failed:", err);
        await event.data!.ref.update({ status: "failed" });
      }
      return;
    }

    // ── WhatsApp channel (default) ────────────────────────────────────────────
    const formatted = formatPhone(phone);
    if (!formatted) {
      await event.data!.ref.update({ status: "invalid_phone" });
      return;
    }

    const phoneSuffix = registrationPhone(phone);
    const sentWithButton = await sendWhatsAppTemplate({
      phoneNumberId:  ctx.phoneNumberId,
      accessToken:    ctx.accessToken,
      to:             formatted,
      templateName:   TEMPLATES.invitation,
      bodyParams:     textParams(firstName),
      // Template URL button base must end at ?telefono= and this suffix is the 10 digits.
      ...(phoneSuffix ? { urlButton: { index: 0, text: phoneSuffix } } : {}),
      idempotencyKey: `inv:${inviteId}`,
      event:          "invitation_sent",
    });
    // If the approved template has no URL button, put the link in the name variable.
    const sentWithBody = sentWithButton || await sendWhatsAppTemplate({
      phoneNumberId:  ctx.phoneNumberId,
      accessToken:    ctx.accessToken,
      to:             formatted,
      templateName:   TEMPLATES.invitation,
      bodyParams:     textParams(`${firstName}. Completa tu registro: ${link}`),
      idempotencyKey: `inv:${inviteId}:body`,
      event:          "invitation_sent",
    });
    // Last resort: the original greeting, so the invite still arrives.
    const sent = sentWithBody || await sendWhatsAppTemplate({
      phoneNumberId:  ctx.phoneNumberId,
      accessToken:    ctx.accessToken,
      to:             formatted,
      templateName:   TEMPLATES.invitation,
      bodyParams:     textParams(firstName),
      idempotencyKey: `inv:${inviteId}:plain`,
      event:          "invitation_sent",
    });

    await event.data!.ref.update({
      status: sent ? "sent" : "failed",
      sentAt: admin.firestore.Timestamp.now(),
    });
  }
);

// ─── 7. whatsappWebhook ───────────────────────────────────────────────────────
// HTTPS endpoint registered in Meta Business Manager.
// Handles:
//   GET  — challenge verification (Meta calls this once when you configure it)
//   POST — incoming status updates (sent, delivered, read, failed)

export const whatsappWebhook = onRequest(
  {
    region:         REGION,
    secrets:        [...WH_SECRETS, waToken, waPhoneId],
    timeoutSeconds: 60,
    // Raw body needed for HMAC validation — do NOT use bodyParser middleware
    invoker:        "public",
  },
  async (req, res) => {
    // ── GET: Meta challenge verification ──────────────────────────────────────
    if (req.method === "GET") {
      const mode      = req.query["hub.mode"];
      const token     = req.query["hub.verify_token"];
      const challenge = req.query["hub.challenge"];

      if (mode === "subscribe" && token === waWebhookSecret.value().trim()) {
        console.log("[Webhook] ✅ Verified");
        res.status(200).send(challenge);
      } else {
        console.warn("[Webhook] ❌ Verification failed");
        res.status(403).send("Forbidden");
      }
      return;
    }

    // ── POST: status updates ──────────────────────────────────────────────────
    if (req.method === "POST") {
      // Validate signature
      const sigHeader = (req.headers["x-hub-signature-256"] as string) ?? "";
      // Cloud Run provides the raw body in req.rawBody (Buffer)
      const rawBody: Buffer = (req as unknown as { rawBody: Buffer }).rawBody;

      if (!rawBody) {
        console.error("[Webhook] No rawBody — ensure invoker is public and no middleware strips it");
        res.status(400).send("Bad Request");
        return;
      }

      if (!validateWebhookSignature(rawBody, sigHeader, waAppSecret.value())) {
        console.warn("[Webhook] ❌ Invalid signature");
        res.status(403).send("Forbidden");
        return;
      }

      // Initialize Claude with API key (resolved secret, available inside handler)
      initClaudeAI(anthropicApiKey.value());
      initConversationsAI(anthropicApiKey.value());

      // Respond to Meta immediately — avoids timeout retries
      res.status(200).send("OK");

      // Process the payload in the background (Cloud Run keeps container alive)
      const payload = req.body as WebhookPayload;
      if (payload.object !== "whatsapp_business_account") return;

      const updates: Promise<void>[] = [];

      for (const entry of payload.entry ?? []) {
        for (const change of entry.changes ?? []) {
          const value = change.value;

          // Status updates (sent, delivered, read, failed)
          for (const status of value.statuses ?? []) {
            const mappedStatus = mapMetaStatus(status.status);
            if (mappedStatus) {
              updates.push(updateWaStatusByWamid(status.id, mappedStatus));
            }
          }

          // Incoming messages
          for (const rawMsg of value.messages ?? []) {
            // Normalize button presses to text so intent detection handles them.
            // Use the payload (id) to map to a known phrase, falling back to title.
            const buttonPayload =
              rawMsg.type === "interactive" &&
              (rawMsg.interactive?.type === "button_reply" || rawMsg.interactive?.type === "list_reply")
                ? (rawMsg.interactive?.button_reply?.id ?? rawMsg.interactive?.list_reply?.id ?? "")
                : rawMsg.type === "button"
                ? (rawMsg.button?.payload || rawMsg.button?.text || "")
                : null;
            const PAYLOAD_TEXT: Record<string, string> = {
              INTERESTED:     "me interesa",
              NOT_INTERESTED: "no gracias",
            };
            const buttonTitle = buttonPayload
              ? (PAYLOAD_TEXT[buttonPayload] ??
                  rawMsg.interactive?.button_reply?.title ??
                  rawMsg.interactive?.list_reply?.title ??
                  rawMsg.button?.text ??
                  buttonPayload)
              : null;

            const msg = buttonTitle
              ? { ...rawMsg, type: "text", text: { body: buttonTitle } }
              : rawMsg;

            const bodyText = msg.text?.body ?? buttonTitle ?? null;

            console.log(`[Webhook] Incoming msg from ${msg.from}: type=${rawMsg.type}${buttonTitle ? ` btn="${buttonTitle}"` : ""}`);

            // Log to Firestore for audit / human follow-up
            updates.push(
              admin.firestore().collection(WA_COLLECTION).add({
                type:        "inbound",
                from:        msg.from,
                waMessageId: msg.id,
                timestamp:   msg.timestamp,
                msgType:     rawMsg.type,
                text:        bodyText,
                contextId:   msg.context?.id ?? null,
                createdAt:   admin.firestore.Timestamp.now(),
              }).then(() => { /* void */ })
            );

            // Process text and button messages through the conversational bot
            if (msg.type === "text" && bodyText) {
              updates.push(
                handleIncomingMessage(msg as IncomingMsg, {
                  phoneNumberId: waPhoneId.value(),
                  accessToken:   waToken.value(),
                }).catch((err) =>
                  console.error("[WA-Bot] handleIncomingMessage error:", err)
                )
              );
            }
          }
        }
      }

      await Promise.allSettled(updates).catch((err) =>
        console.error("[Webhook] Background processing error:", err)
      );
      return;
    }

    res.status(405).send("Method Not Allowed");
  }
);

// ─── 12. reenviarCorreoAsignacion ─────────────────────────────────────────────
// HTTP endpoint to retry a failed assignment email without re-assigning the load.
//
// POST  /reenviarCorreoAsignacion
// Header: X-ElevenLabs-Secret: <secret>
// Body:   { "id_viaje": "<loadId>", "id_transportista": "<carrierId>" }

export const reenviarCorreoAsignacion = onRequest(
  {
    region:         REGION,
    secrets:        [elevenLabsSecret, ...WA_SECRETS],
    timeoutSeconds: 30,
    invoker:        "public",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method Not Allowed" });
      return;
    }

    const incoming = req.headers["x-elevenlabs-secret"];
    if (typeof incoming !== "string" || incoming !== elevenLabsSecret.value()) {
      console.warn("[reenviarCorreo] Rejected — invalid secret");
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const body           = req.body as Record<string, unknown>;
    const idViaje        = typeof body["id_viaje"]        === "string" ? body["id_viaje"].trim()        : "";
    const idTransportista = typeof body["id_transportista"] === "string" ? body["id_transportista"].trim() : "";
    if (!idViaje || !idTransportista) {
      res.status(400).json({ error: "id_viaje e id_transportista son requeridos" });
      return;
    }

    const db = admin.firestore();
    const [loadSnap, carrier] = await Promise.all([
      db.collection("loads").doc(idViaje).get(),
      findUserByUuid(idTransportista),
    ]);

    if (!loadSnap.exists || !carrier) {
      res.status(200).json({ enviado: false, motivo: "not_found" });
      return;
    }

    const loadData   = loadSnap.data()!;
    const reference  = (loadData["reference"]           as string) ?? idViaje;
    const origin     = (loadData["originState"]         as string) ?? "";
    const destination = (loadData["destinationState"]   as string) ?? "";
    const tarifa     = typeof loadData["assignedPriceSinIVA"] === "number"
      ? loadData["assignedPriceSinIVA"] as number
      : null;
    const currency   = (loadData["currency"]            as string) ?? "MXN";
    const firstName  = carrier.name.split(" ")[0];

    const emailNotifId  = `la:${idViaje}:${idTransportista}`;
    const emailNotifRef = db.collection("email_notifications").doc(emailNotifId);
    const ctx           = buildContext();

    try {
      await ctx.mailer.sendMail(
        buildAssignedMailOptions(
          firstName, reference, origin, destination,
          tarifa, currency, carrier.email, ctx.fromEmail,
        )
      );
      await emailNotifRef.set({
        loadId: idViaje, carrierId: idTransportista, to: carrier.email,
        status: "sent", sentAt: admin.firestore.Timestamp.now(),
        attempts: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.Timestamp.now(),
      }, { merge: true });
      console.log(`[reenviarCorreo] Enviado a ${carrier.email} — viaje ${idViaje}`);
      res.status(200).json({ enviado: true, to: carrier.email });
    } catch (e) {
      console.error("[reenviarCorreo] Fallo al enviar:", e);
      await emailNotifRef.set({
        loadId: idViaje, carrierId: idTransportista, to: carrier.email,
        status: "failed", error: String(e),
        attempts: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.Timestamp.now(),
      }, { merge: true });
      res.status(200).json({ enviado: false, motivo: "smtp_error", detalle: String(e) });
    }
  }
);

// ─── 13. checkWhatsApp ────────────────────────────────────────────────────────
// Callable function: verifies if a phone number has WhatsApp by attempting to
// send the cc_invitacion template. Returns { hasWhatsApp: boolean|null }.
// null = transient error (caller should add the number anyway and not block).
// false = error 131026 confirmed (number not on WhatsApp).

// ─── createUserProfile ────────────────────────────────────────────────────────
// Creates the Firestore user profile (and optionally company + phone index)
// using the Admin SDK, which bypasses security rules. Called immediately after
// Firebase Auth createUser to avoid the auth-token propagation race that causes
// the iOS Firestore SDK to get Permission Denied on fresh registrations.

export const createUserProfile = onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes estar autenticado para registrarte");
    }

    const uid  = request.auth.uid;
    const data = request.data as Record<string, unknown>;

    if (!data || typeof data !== "object") {
      throw new HttpsError("invalid-argument", "Datos inválidos");
    }

    const role = data.role as string | undefined;
    if (!["carrier", "independent_operator"].includes(role ?? "")) {
      throw new HttpsError("invalid-argument", "Rol inválido");
    }

    const db    = admin.firestore();
    const batch = db.batch();

    // User document — force security-critical fields server-side
    const { company: companyData, ...userData } = data as Record<string, unknown> & {
      company?: Record<string, unknown>;
    };

    batch.set(db.collection("users").doc(uid), {
      ...userData,
      status:    "pending_approval",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Phone index entry
    const phoneDigits = typeof userData.phoneDigits === "string" ? userData.phoneDigits : "";
    if (/^\d{10,15}$/.test(phoneDigits)) {
      batch.set(db.collection("users_by_phone").doc(phoneDigits), {
        phoneDigits,
        uuid:   userData.uuid,
        name:   userData.name,
        role:   userData.role,
        status: "pending_approval",
      });
    }

    // Company (carriers only)
    if (role === "carrier" && companyData && typeof companyData.id === "string") {
      batch.set(db.collection("companies").doc(companyData.id), {
        ...companyData,
        status:    "pending_approval",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return { success: true };
  }
);

export const checkWhatsApp = onCall(
  { region: REGION, secrets: [...WA_SECRETS] },
  async (request) => {
    const rawPhone = typeof request.data?.phone === "string"
      ? (request.data.phone as string).trim() : "";
    if (!rawPhone) {
      throw new HttpsError("invalid-argument", "Falta el número de teléfono");
    }
    const formatted = formatPhone(rawPhone);
    if (!formatted) {
      throw new HttpsError("invalid-argument", "Formato de teléfono inválido");
    }

    const ctx = buildContext();
    // Timestamp in key allows re-checking the same number without idempotency
    // deduplication blocking the result.
    const safePhone = formatted.replace("+", "");
    const idempotencyKey = `chk:${safePhone}:${Date.now()}`;

    const sent = await sendWhatsAppTemplate({
      phoneNumberId: ctx.phoneNumberId,
      accessToken:   ctx.accessToken,
      to:            formatted,
      templateName:  TEMPLATES.invitation,
      bodyParams:    textParams("Continente Conecta"),
      idempotencyKey,
      event:         "invitation_sent",
    });

    if (!sent) {
      const waDoc = await admin.firestore()
        .collection(WA_COLLECTION).doc(idempotencyKey).get();
      const errStr: string = waDoc.data()?.error ?? "";
      if (errStr.includes("131026")) {
        return { hasWhatsApp: false, phone: formatted };
      }
      // Transient / unknown error — don't block registration
      return { hasWhatsApp: null, phone: formatted };
    }

    return { hasWhatsApp: true, phone: formatted };
  }
);

// ─── Webhook payload types ────────────────────────────────────────────────────

interface WebhookPayload {
  object: string;
  entry: Array<{
    id: string;
    changes: Array<{
      value: {
        messaging_product: string;
        statuses?: Array<{ id: string; status: string; timestamp: string; recipient_id: string }>;
        messages?: Array<{
          id: string; from: string; timestamp: string; type: string;
          text?: { body: string };
          context?: { id: string };
          interactive?: {
            type: string;
            button_reply?: { id: string; title: string };
            list_reply?:   { id: string; title: string };
          };
          button?: { payload: string; text: string };
        }>;
      };
      field: string;
    }>;
  }>;
}

// Maps Meta's status strings to our WaStatus type
function mapMetaStatus(s: string): WaStatus | null {
  switch (s) {
    case "sent":      return "sent";
    case "delivered": return "delivered";
    case "read":      return "read";
    case "failed":    return "failed";
    default:          return null;
  }
}

// ─── 10. consultarViaje ───────────────────────────────────────────────────────
// HTTP endpoint consumed by ElevenLabs AI agent to check load availability
// in real time during a phone call.
//
// POST  /consultarViaje
// Header: X-ElevenLabs-Secret: <secret>          (required)
// Body:   { "id_viaje": "<Firestore document ID>" }
//
// Response 200:
//   { "id_viaje": "...", "disponible": true|false, "estado": "<status>" }
//
// disponible = true  ONLY when:
//   status === "Publicado"  AND  deadline is in the future
// All other statuses (Asignado, Cancelado, Entregado, etc.) → disponible: false
//
// READ-ONLY — never modifies Firestore, never sends notifications.
// Secrets: ELEVENLABS_SECRET, ELEVENLABS_AUTHORIZED_PUBLISHER

// All statuses from LoadStatus enum that are definitively not available
const NON_AVAILABLE_STATUSES = new Set([
  "Asignado",
  "En camino a recolección",
  "En origen",
  "Cargado",
  "En tránsito",
  "Entregado",
  "Cancelado",
]);

export const consultarViaje = onRequest(
  {
    region:         REGION,       // us-central1
    secrets:        [elevenLabsSecret, elevenLabsPublisher],
    timeoutSeconds: 30,
    invoker:        "public",
  },
  async (req, res) => {

    // ── Only POST ─────────────────────────────────────────────────────────────
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method Not Allowed" });
      return;
    }

    // ── Auth: validate shared secret header ───────────────────────────────────
    const incoming = req.headers["x-elevenlabs-secret"];
    if (
      typeof incoming !== "string" ||
      incoming !== elevenLabsSecret.value()
    ) {
      // Log without echoing the expected value
      console.warn("[consultarViaje] Rejected — missing or invalid X-ElevenLabs-Secret");
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    // ── Input validation ──────────────────────────────────────────────────────
    const body    = req.body as Record<string, unknown>;
    const idViaje = typeof body["id_viaje"] === "string" ? body["id_viaje"].trim() : "";
    if (!idViaje) {
      res.status(400).json({ error: "id_viaje is required and must be a non-empty string" });
      return;
    }

    // ── Fetch load from Firestore (read-only) ─────────────────────────────────
    // Intento primario: doc ID == idViaje (caso normal cuando la app iOS persiste la carga).
    // Fallback: query por campo "id" para cubrir documentos con doc ID distinto al campo.
    let snap: FirebaseFirestore.DocumentSnapshot | FirebaseFirestore.QueryDocumentSnapshot;
    try {
      const directSnap = await admin.firestore().collection("loads").doc(idViaje).get();
      if (directSnap.exists) {
        snap = directSnap;
        console.log(`[consultarViaje] Encontrada por doc ID: ${idViaje}`);
      } else {
        console.log(`[consultarViaje] Doc ID no existe, buscando por campo id...`);
        const q = await admin.firestore()
          .collection("loads")
          .where("id", "==", idViaje)
          .limit(1)
          .get();
        if (q.empty) {
          console.log(`[consultarViaje] No encontrada ni por doc ID ni por campo id: ${idViaje}`);
          res.status(200).json({ id_viaje: idViaje, disponible: false, estado: "no_encontrada" });
          return;
        }
        snap = q.docs[0];
        console.log(`[consultarViaje] Encontrada por campo id, doc real ID: ${snap.id}`);
      }
    } catch (err) {
      console.error("[consultarViaje] Firestore read error:", err);
      res.status(500).json({ error: "Internal error" });
      return;
    }

    const data        = snap.data()!;
    const status      = (data["status"]      as string) ?? "";
    const publishedBy = (data["publishedBy"] as string) ?? "";
    const deadline    = data["deadline"]     as FirebaseFirestore.Timestamp | undefined;

    // ── Company check: only expose loads from the authorized publisher ─────────
    // ELEVENLABS_AUTHORIZED_PUBLISHER must be stored with printf (not echo) to
    // avoid trailing newlines. Both sides are trimmed defensively.
    // Returns the same shape as "not found" to avoid disclosing doc existence.
    const authorizedPublisher = elevenLabsPublisher.value().trim();
    if (authorizedPublisher && publishedBy.trim() !== authorizedPublisher) {
      console.warn(`[consultarViaje] Company mismatch — idViaje=${idViaje}`);
      res.status(200).json({ id_viaje: idViaje, disponible: false, estado: "no_encontrada" });
      return;
    }

    // ── Availability: mirrors LoadModel.isOpen from the iOS app ──────────────
    // isOpen = status == .published && Date() < deadline && !isFull
    // Since confirmedUnitCount is not yet persisted to Firestore, we rely on
    // status: when all units are taken, AppStore sets status = "Asignado".
    const deadlineDate = deadline?.toDate();
    const now          = new Date();
    const disponible   = status === "Publicado" &&
                         deadlineDate != null &&
                         deadlineDate > now &&
                         !NON_AVAILABLE_STATUSES.has(status);

    console.log(
      `[consultarViaje] id=${idViaje} status="${status}" ` +
      `deadline=${deadlineDate?.toISOString() ?? "none"} disponible=${disponible}`
    );

    res.status(200).json({ id_viaje: idViaje, disponible, estado: status });
  }
);

// ─── 11. asignarViaje ─────────────────────────────────────────────────────────
// HTTP endpoint consumed by ElevenLabs AI agent to assign a load to a carrier
// after negotiating terms on a phone call.
//
// POST  /asignarViaje
// Header: X-ElevenLabs-Secret: <secret>   (required)
// Body:
//   {
//     "id_viaje":                "<UUID>",
//     "id_transportista":        "<UUID>",
//     "tarifa_acordada_sin_iva": <number>,      // tarifa sin IVA acordada
//     "moneda":                  "MXN" | "USD",
//     "clave_idempotencia":      "<string>"     // unique per negotiation attempt
//   }
//
// Response 200 — success:
//   { "asignado": true, "id_viaje", "id_transportista", "referencia",
//     "tarifa_acordada_sin_iva", "moneda", "estado": "Asignado" }
//
// Response 200 — failure:
//   { "asignado": false, "motivo": "<code>", "detalle": "<human-readable>" }
//
// Price validation:
//   offeredPrice (Firestore) = máximo autorizado por Continente Cargo.
//   If includesVAT=true  → maxSinIVA = offeredPrice / 1.16
//   If includesVAT=false → maxSinIVA = offeredPrice
//   Rejects if tarifa_acordada_sin_iva > maxSinIVA.
//
// Idempotency:
//   Stored in ai_assignments/{clave_idempotencia} upon successful assignment.
//   Same clave + same data → returns cached result without re-assigning.
//   Same clave + different data → rejected with "idempotencia_conflicto".
//   Failed assignments are NOT stored; agent may retry with a new clave.
//
// Notifications:
//   onLoadAssigned Firestore trigger fires automatically on status→"Asignado".
//   This function does NOT send WhatsApp or email (would duplicate them).
//   Carta Instrucción (CI) is uploaded separately by admin — not sent here.

interface AssignmentTxResult {
  cached:     boolean;
  asignado:   boolean;
  motivo?:    string;
  detalle?:   string;
  referencia?: string;
}

export const asignarViaje = onRequest(
  {
    region:         REGION,
    secrets:        [elevenLabsSecret, elevenLabsPublisher],
    timeoutSeconds: 60,
    invoker:        "public",
  },
  async (req, res) => {

    // ── Only POST ─────────────────────────────────────────────────────────────
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method Not Allowed" });
      return;
    }

    // ── Auth: shared secret ───────────────────────────────────────────────────
    const incoming = req.headers["x-elevenlabs-secret"];
    if (typeof incoming !== "string" || incoming !== elevenLabsSecret.value()) {
      console.warn("[asignarViaje] Rejected — missing or invalid X-ElevenLabs-Secret");
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    // ── Parse body ────────────────────────────────────────────────────────────
    const body              = req.body as Record<string, unknown>;
    const idViaje           = typeof body["id_viaje"]                === "string" ? body["id_viaje"].trim()                : "";
    const idTransportista   = typeof body["id_transportista"]        === "string" ? body["id_transportista"].trim()        : "";
    const tarifaSinIVARaw   = body["tarifa_acordada_sin_iva"];
    const tarifaSinIVA      = typeof tarifaSinIVARaw === "number"    ? tarifaSinIVARaw                                     : null;
    const moneda            = typeof body["moneda"]                  === "string" ? body["moneda"].trim().toUpperCase()    : "";
    const claveIdempotencia = typeof body["clave_idempotencia"]      === "string" ? body["clave_idempotencia"].trim()      : "";

    if (!idViaje)           { res.status(400).json({ error: "id_viaje requerido" }); return; }
    if (!idTransportista)   { res.status(400).json({ error: "id_transportista requerido" }); return; }
    if (tarifaSinIVA === null || tarifaSinIVA < 0) {
      res.status(400).json({ error: "tarifa_acordada_sin_iva debe ser un número >= 0" });
      return;
    }
    if (!["MXN", "USD"].includes(moneda)) {
      res.status(400).json({ error: "moneda debe ser MXN o USD" });
      return;
    }
    if (!claveIdempotencia) { res.status(400).json({ error: "clave_idempotencia requerida" }); return; }

    const db       = admin.firestore();
    const loadRef  = db.collection("loads").doc(idViaje);
    const idempRef = db.collection("ai_assignments").doc(claveIdempotencia);
    const now      = new Date();

    // ── Validate carrier (outside transaction — read-only, no contention risk) ─
    const carrier = await findUserByUuid(idTransportista);
    if (!carrier) {
      res.status(200).json({
        asignado: false,
        motivo:   "transportista_no_encontrado",
        detalle:  "No existe un usuario con ese id_transportista.",
      });
      return;
    }
    if (carrier.status !== "approved") {
      res.status(200).json({
        asignado: false,
        motivo:   "transportista_no_habilitado",
        detalle:  `El transportista tiene status '${carrier.status}'.`,
      });
      return;
    }
    if (carrier.role === "admin") {
      res.status(200).json({
        asignado: false,
        motivo:   "transportista_invalido",
        detalle:  "El id_transportista corresponde a un administrador, no a un transportista.",
      });
      return;
    }

    // ── Firestore transaction: idempotency + availability + assignment ─────────
    // All reads come before all writes (Firestore requirement).
    // Writes only happen on the success path; failures skip all writes.
    let txResult: AssignmentTxResult;
    try {
      txResult = await db.runTransaction(async (tx) => {

        // ── 1. Idempotency check ───────────────────────────────────────────────
        const idempSnap = await tx.get(idempRef);
        if (idempSnap.exists) {
          const prev = idempSnap.data()!;
          const sameData =
            prev["idViaje"]          === idViaje &&
            prev["idTransportista"]  === idTransportista &&
            prev["tarifa"]           === tarifaSinIVA &&
            prev["moneda"]           === moneda;
          if (sameData) {
            return {
              cached:     true,
              asignado:   prev["asignado"] as boolean,
              referencia: prev["referencia"] as string | undefined,
              motivo:     prev["motivo"]    as string | undefined,
              detalle:    prev["detalle"]   as string | undefined,
            };
          }
          return {
            cached:   false,
            asignado: false,
            motivo:   "idempotencia_conflicto",
            detalle:  "La clave_idempotencia ya fue usada con datos diferentes. Usa una clave nueva.",
          };
        }

        // ── 2. Fetch load ──────────────────────────────────────────────────────
        const loadSnap = await tx.get(loadRef);
        if (!loadSnap.exists) {
          return {
            cached: false, asignado: false,
            motivo:  "viaje_no_encontrado",
            detalle: "No existe una carga con ese id_viaje.",
          };
        }
        const loadData = loadSnap.data()!;

        // ── 3. Publisher / company check ──────────────────────────────────────
        // Returns same shape as "not found" to avoid disclosing internal IDs.
        const publishedBy         = ((loadData["publishedBy"] as string) ?? "").trim();
        const authorizedPublisher = elevenLabsPublisher.value().trim();
        if (authorizedPublisher && publishedBy !== authorizedPublisher) {
          console.warn(`[asignarViaje] Company mismatch — idViaje=${idViaje}`);
          return {
            cached: false, asignado: false,
            motivo:  "viaje_no_encontrado",
            detalle: "El viaje no pertenece a la empresa autorizada.",
          };
        }

        // ── 4. Availability ───────────────────────────────────────────────────
        const status   = (loadData["status"]   as string) ?? "";
        const deadline = (loadData["deadline"] as admin.firestore.Timestamp | undefined)?.toDate();

        if (status !== "Publicado") {
          return {
            cached: false, asignado: false,
            motivo:  "carga_no_disponible",
            detalle: `La carga tiene status '${status}' y no está disponible para asignación.`,
          };
        }
        if (!deadline || deadline <= now) {
          return {
            cached: false, asignado: false,
            motivo:  "plazo_expirado",
            detalle: "El plazo para participar en esta carga ha vencido.",
          };
        }
        if (loadData["assignedCarrierId"]) {
          return {
            cached: false, asignado: false,
            motivo:  "carga_ya_asignada",
            detalle: "La carga ya tiene un transportista asignado.",
          };
        }

        // ── 5. Price authorization ─────────────────────────────────────────────
        // maxAuthorizedPriceSinIVA is the explicit ceiling set by the admin.
        // It is always sin-IVA and independent of offeredPrice.
        // If absent, AI assignment is not enabled for this load — reject clearly.
        const maxSinIVA = typeof loadData["maxAuthorizedPriceSinIVA"] === "number"
          ? loadData["maxAuthorizedPriceSinIVA"] as number
          : null;
        if (maxSinIVA === null) {
          return {
            cached: false, asignado: false,
            motivo:  "maximo_no_definido",
            detalle: "La carga no tiene maxAuthorizedPriceSinIVA definido. " +
                     "El administrador debe autorizarlo antes de habilitar asignación por IA.",
          };
        }
        // Allow 1-cent rounding tolerance for floating-point arithmetic
        if (tarifaSinIVA - maxSinIVA > 0.01) {
          return {
            cached: false, asignado: false,
            motivo:  "tarifa_excede_maximo",
            detalle: `La tarifa ${tarifaSinIVA} ${moneda} s/IVA supera el máximo autorizado ` +
                     `(maxAuthorizedPriceSinIVA) de ${maxSinIVA.toFixed(2)} ${moneda} s/IVA.`,
          };
        }

        // ── 6. Currency must match load currency ──────────────────────────────
        const loadCurrency = ((loadData["currency"] as string) ?? "").toUpperCase();
        if (moneda !== loadCurrency) {
          return {
            cached: false, asignado: false,
            motivo:  "moneda_incorrecta",
            detalle: `La carga usa ${loadCurrency} y la tarifa fue acordada en ${moneda}.`,
          };
        }

        // ── 7. Build status history entry ─────────────────────────────────────
        const historyEntry = {
          id:            randomUUID(),
          status:        "Asignado",
          changedBy:     publishedBy,
          changedByName: "Agente IA / ElevenLabs",
          changedAt:     admin.firestore.Timestamp.now(),
          notes:         `Tarifa acordada: ${tarifaSinIVA} ${moneda} s/IVA. Clave: ${claveIdempotencia}`,
        };
        const currentHistory = (loadData["statusHistory"] as unknown[]) ?? [];

        // ── 8. Write: update load (only changed fields) ───────────────────────
        tx.update(loadRef, {
          status:               "Asignado",
          assignedCarrierId:    idTransportista,
          assignedPriceSinIVA:  tarifaSinIVA,
          statusHistory:        [...currentHistory, historyEntry],
        });

        // ── 9. Write: offer record for audit trail (mirrors AppStore.takeLoad) ─
        const offerId  = randomUUID();
        const offerRef = db.collection("offers").doc(offerId);
        tx.set(offerRef, {
          id:                 offerId,
          loadId:             idViaje,
          carrierId:          idTransportista,
          carrierName:        carrier.name,
          amount:             tarifaSinIVA,
          currency:           moneda,
          isAvailabilityOnly: false,
          status:             "Ganadora",
          submittedAt:        admin.firestore.Timestamp.now(),
          notes:              `Asignación por agente IA ElevenLabs. Clave: ${claveIdempotencia}`,
          availableUnitCount: 1,
        });

        // ── 10. Write: idempotency record ─────────────────────────────────────
        const referencia = (loadData["reference"] as string) ?? "";
        tx.set(idempRef, {
          idViaje,
          idTransportista,
          tarifa:     tarifaSinIVA,
          moneda,
          asignado:   true,
          referencia,
          assignedAt: admin.firestore.Timestamp.now(),
        });

        return { cached: false, asignado: true, referencia };
      });
    } catch (err) {
      console.error("[asignarViaje] Transaction error:", err);
      res.status(500).json({ error: "Internal error al registrar la asignación" });
      return;
    }

    // ── Build response ─────────────────────────────────────────────────────────
    if (txResult.asignado) {
      console.log(
        `[asignarViaje] Asignado${txResult.cached ? " (idempotente)" : ""}: ` +
        `viaje=${idViaje} transportista=${idTransportista} tarifa=${tarifaSinIVA} ${moneda}`
      );
      res.status(200).json({
        asignado:               true,
        id_viaje:               idViaje,
        id_transportista:       idTransportista,
        referencia:             txResult.referencia ?? "",
        tarifa_acordada_sin_iva: tarifaSinIVA,
        moneda,
        estado:                 "Asignado",
        ...(txResult.cached ? { idempotente: true } : {}),
      });
    } else {
      console.warn(
        `[asignarViaje] No asignado: motivo=${txResult.motivo} viaje=${idViaje}`
      );
      res.status(200).json({
        asignado: false,
        motivo:   txResult.motivo  ?? "error_desconocido",
        detalle:  txResult.detalle ?? "",
      });
    }
  }
);

// ─── 12. buscarCargasPublicadas ───────────────────────────────────────────────
// HTTP endpoint for the ElevenLabs incoming-calls agent ("Camilo") to search
// available loads in real time during a phone call.
//
// POST  /buscarCargasPublicadas
// Header: X-ElevenLabs-Secret: <secret>   (required)
// Body (all fields optional):
//   {
//     "origen":         "<ciudad o estado>",  // partial match, case-insensitive
//     "destino":        "<ciudad o estado>",
//     "tipo_unidad":    "<tipo de equipo>",   // partial match, case-insensitive
//     "fecha_carga":    "YYYY-MM-DD",          // día de recolección en America/Monterrey
//     "referencia":     "<referencia>",        // partial match, case-insensitive
//     "max_resultados": 3                      // 1–5, default 3
//   }
//
// Response 200:
//   { "cargas": [...], "total_encontradas": N, "hay_mas": bool, "mensaje": "..." }
//
// SECURITY: Never exposes maxAuthorizedPriceSinIVA, assignedPriceSinIVA,
//           clientContactName, clientContactPhone, exactPickupAddress,
//           exactDeliveryAddress, publishedBy, or any other internal field.
// READ-ONLY: Does not modify Firestore or send notifications.
// Secrets: ELEVENLABS_SECRET, ELEVENLABS_AUTHORIZED_PUBLISHER
//
// Required composite index (firestore.indexes.json):
//   loads → publishedBy ASC + status ASC + deadline ASC

const MONTERREY_TZ = "America/Monterrey";

// Fields that are safe to expose to the ElevenLabs agent (no internal pricing/contact data)
const PRIVATE_LOAD_FIELDS = new Set([
  "maxAuthorizedPriceSinIVA",
  "assignedPriceSinIVA",
  "clientContactName",
  "clientContactPhone",
  "exactPickupAddress",
  "exactDeliveryAddress",
  "publishedBy",
  "assignedCarrierId",
  "assignedUnitId",
  "urgentRepost",
  "notificationChannels",
  "statusHistory",
]);

function toPublicLoad(docId: string, data: Record<string, unknown>): Record<string, unknown> {
  const result: Record<string, unknown> = { id: (data["id"] as string) || docId };
  for (const [key, val] of Object.entries(data)) {
    if (key === "id" || PRIVATE_LOAD_FIELDS.has(key)) continue;
    if (val === undefined || val === null) continue;
    // Convert Firestore Timestamps to human-readable Spanish dates
    if (typeof (val as Record<string, unknown>)["toDate"] === "function") {
      const date = (val as admin.firestore.Timestamp).toDate();
      result[key] = date.toLocaleDateString("es-MX", {
        timeZone:  MONTERREY_TZ,
        weekday:   "long",
        year:      "numeric",
        month:     "long",
        day:       "numeric",
      });
    } else {
      result[key] = val;
    }
  }
  return result;
}

function tsToMonterreyDateStr(ts: admin.firestore.Timestamp): string {
  // Returns "YYYY-MM-DD" in Monterrey local time
  return ts.toDate().toLocaleDateString("en-CA", { timeZone: MONTERREY_TZ });
}

export const buscarCargasPublicadas = onRequest(
  {
    region:         REGION,
    secrets:        [elevenLabsSecret, elevenLabsPublisher],
    timeoutSeconds: 30,
    invoker:        "public",
  },
  async (req, res) => {

    // ── Only POST ─────────────────────────────────────────────────────────────
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method Not Allowed" });
      return;
    }

    // ── Auth: shared secret ───────────────────────────────────────────────────
    const incoming = req.headers["x-elevenlabs-secret"];
    if (typeof incoming !== "string" || incoming !== elevenLabsSecret.value()) {
      console.warn("[buscarCargasPublicadas] Rejected — invalid X-ElevenLabs-Secret");
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    // ── Parse optional filters ────────────────────────────────────────────────
    const body         = req.body as Record<string, unknown>;
    const origen       = typeof body["origen"]       === "string" ? body["origen"].trim().toLowerCase()       : "";
    const destino      = typeof body["destino"]      === "string" ? body["destino"].trim().toLowerCase()      : "";
    const tipoUnidad   = typeof body["tipo_unidad"]  === "string" ? body["tipo_unidad"].trim().toLowerCase()  : "";
    const fechaCarga   = typeof body["fecha_carga"]  === "string" ? body["fecha_carga"].trim()                : "";
    const referencia   = typeof body["referencia"]   === "string" ? body["referencia"].trim().toLowerCase()   : "";
    const maxRaw       = typeof body["max_resultados"] === "number" ? (body["max_resultados"] as number)      : 3;
    const maxResultados = Math.min(Math.max(Math.floor(maxRaw), 1), 5);

    // Validate fecha_carga format if provided
    if (fechaCarga && !/^\d{4}-\d{2}-\d{2}$/.test(fechaCarga)) {
      res.status(400).json({ error: "fecha_carga must be YYYY-MM-DD" });
      return;
    }

    // ── Authorized publisher ──────────────────────────────────────────────────
    const authorizedPublisher = elevenLabsPublisher.value().trim();

    // ── Firestore query: deadline > now ──────────────────────────────────────────
    // Uses only a single-field inequality on deadline (auto-indexed by Firestore).
    // status and publishedBy are checked in-memory to avoid composite index requirements.
    const now = admin.firestore.Timestamp.now();
    let snapshot: FirebaseFirestore.QuerySnapshot;
    try {
      snapshot = await admin.firestore()
        .collection("loads")
        .where("deadline", ">",  now)
        .orderBy("deadline", "asc")
        .limit(200)
        .get();
    } catch (err) {
      console.error("[buscarCargasPublicadas] Firestore query error:", err);
      res.status(500).json({ error: "Error al consultar cargas. Intenta de nuevo." });
      return;
    }

    // ── In-memory filters ─────────────────────────────────────────────────────
    console.log(`[buscarCargasPublicadas] Firestore returned ${snapshot.size} docs with deadline > now`);
    const matched: Array<Record<string, unknown>> = [];
    for (const doc of snapshot.docs) {
      const d = doc.data();

      // status must be "Publicado"
      if ((d["status"] as string) !== "Publicado") continue;

      // company check: only loads from the authorized publisher
      if (authorizedPublisher && ((d["publishedBy"] as string) ?? "").trim() !== authorizedPublisher) continue;

      // origen: partial match on originCity or originState
      if (origen) {
        const city  = ((d["originCity"]  as string) ?? "").toLowerCase();
        const state = ((d["originState"] as string) ?? "").toLowerCase();
        if (!city.includes(origen) && !state.includes(origen)) continue;
      }

      // destino: partial match on destinationCity or destinationState
      if (destino) {
        const city  = ((d["destinationCity"]  as string) ?? "").toLowerCase();
        const state = ((d["destinationState"] as string) ?? "").toLowerCase();
        if (!city.includes(destino) && !state.includes(destino)) continue;
      }

      // tipo_unidad: partial match on equipmentType
      if (tipoUnidad) {
        const eq = ((d["equipmentType"] as string) ?? "").toLowerCase();
        if (!eq.includes(tipoUnidad)) continue;
      }

      // fecha_carga: pickupDate falls on that calendar day in Monterrey time
      if (fechaCarga) {
        const pickupTs = d["pickupDate"] as admin.firestore.Timestamp | undefined;
        if (!pickupTs || tsToMonterreyDateStr(pickupTs) !== fechaCarga) continue;
      }

      // referencia: partial match on reference
      if (referencia) {
        const ref = ((d["reference"] as string) ?? "").toLowerCase();
        if (!ref.includes(referencia)) continue;
      }

      matched.push(toPublicLoad(doc.id, d));
    }

    // ── Paginate results ──────────────────────────────────────────────────────
    const totalEncontradas = matched.length;
    const hayMas = totalEncontradas > maxResultados;
    const cargas = matched.slice(0, maxResultados);

    // ── Human-readable summary ────────────────────────────────────────────────
    let mensaje: string;
    if (cargas.length === 0) {
      mensaje = "No encontré cargas disponibles con los criterios indicados en este momento.";
    } else if (cargas.length === 1) {
      mensaje = `Encontré 1 carga disponible.`;
    } else {
      mensaje = `Encontré ${cargas.length} cargas disponibles` + (hayMas ? ` (hay más resultados no mostrados).` : ".");
    }

    console.log(
      `[buscarCargasPublicadas] origen="${origen}" destino="${destino}" ` +
      `tipoUnidad="${tipoUnidad}" fechaCarga="${fechaCarga}" referencia="${referencia}" ` +
      `total=${totalEncontradas} returned=${cargas.length}`
    );

    res.status(200).json({ cargas, total_encontradas: totalEncontradas, hay_mas: hayMas, mensaje });
  }
);

// ─── importCarrierDirectory ───────────────────────────────────────────────────
// Callable: admin-only. Upserts every record from carrierDirectory.json into
// carrier_preprofiles/{phone}. Safe to call repeatedly — preserves status field
// so already-invited/registered carriers are not reset.

interface CarrierEntry {
  companyName: string;
  contactName: string;
  phone: string;
  email: string;
  baseCity: string;
  equipmentTypes: string[];
  coverageZones: string[];
  handlesLocal: boolean;
  handlesLTL: boolean;
  handlesHazmat: boolean;
  handlesImpoExpo: boolean;
  status: string;
}

export const importCarrierDirectory = onCall(
  { region: REGION },
  async (request) => {
    // Only approved admins can call this
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Login required");

    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const userData = userDoc.data();
    if (!userData || userData["role"] !== "admin" || userData["status"] !== "approved") {
      throw new HttpsError("permission-denied", "Admin only");
    }

    const db = admin.firestore();
    const carriers = carrierDirectory as CarrierEntry[];
    const DATA_FIELDS = [
      "companyName","contactName","phone","email","baseCity",
      "equipmentTypes","coverageZones","handlesLocal","handlesLTL",
      "handlesHazmat","handlesImpoExpo","importedAt",
    ];

    // Process in chunks of 400 (Firestore batch limit is 500)
    const now = admin.firestore.Timestamp.now();
    let count = 0;
    const CHUNK = 400;

    for (let i = 0; i < carriers.length; i += CHUNK) {
      const chunk = carriers.slice(i, i + CHUNK);
      const batch = db.batch();
      for (const c of chunk) {
        const docId = c.phone || c.email.replace(/[^a-zA-Z0-9]/g, "_");
        if (!docId) continue;
        const ref = db.collection("carrier_preprofiles").doc(docId);
        // mergeFields: update data fields only; status is intentionally excluded
        // so existing invitation status (sent/registered) is never overwritten.
        // For brand-new docs, missing status is treated as "pending_invitation" in the app.
        batch.set(ref, {
          companyName:    c.companyName,
          contactName:    c.contactName,
          phone:          c.phone,
          email:          c.email,
          baseCity:       c.baseCity,
          equipmentTypes: c.equipmentTypes,
          coverageZones:  c.coverageZones,
          handlesLocal:   c.handlesLocal,
          handlesLTL:     c.handlesLTL,
          handlesHazmat:  c.handlesHazmat,
          handlesImpoExpo: c.handlesImpoExpo,
          importedAt:     now,
        }, { mergeFields: DATA_FIELDS });
        count++;
      }
      await batch.commit();
    }

    console.log(`[importCarrierDirectory] Upserted ${count} carrier pre-profiles`);
    return { imported: count };
  }
);
