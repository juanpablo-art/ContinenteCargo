import * as nodemailer from "nodemailer";

// ─── Transporter factory ──────────────────────────────────────────────────────
// Called per-invocation so the secret values are resolved at runtime.

export function getMailTransport(gmailUser: string, gmailPass: string) {
  return nodemailer.createTransport({
    service: "gmail",
    auth: { user: gmailUser, pass: gmailPass },
  });
}

// ─── Email helpers ────────────────────────────────────────────────────────────

interface LoadMailParams {
  firstName: string;
  reference: string;
  origin: string;
  destination: string;
  equipment: string;
  unitCount: number;
  priceStr: string;
  currency: string;
  assignmentMode: string;
  isUrgent: boolean;
  pickupDateStr?: string;
}

export function buildLoadMailOptions(
  p: LoadMailParams,
  to: string,
  from: string
): nodemailer.SendMailOptions {
  const subject = p.isUrgent
    ? `🚨 URGENTE: ${p.reference} — posicionamiento inmediato`
    : `¡Nueva carga disponible! ${p.reference}`;

  const urgentBanner = p.isUrgent
    ? `<p style="background:#fff3cd;border:1px solid #ffc107;border-radius:8px;
               padding:10px;color:#856404;font-weight:bold;">
         ⚠️ Esta carga requiere posicionamiento urgente. ¡Responde lo antes posible!
       </p>`
    : "";

  const actionVerb = p.isUrgent
    ? "Esta carga requiere posicionamiento URGENTE."
    : "Hay una nueva carga disponible en tu ruta:";

  const pickupLine = p.pickupDateStr ? `Posicionamiento: ${p.pickupDateStr}\n` : "";

  const text =
    `Hola ${p.firstName},\n\n${actionVerb}\n\n` +
    `Referencia: ${p.reference}\n` +
    `Ruta: ${p.origin} → ${p.destination}\n` +
    pickupLine +
    `Equipo: ${p.equipment}\n` +
    `Unidades: ${p.unitCount}\n` +
    `Precio: $${p.priceStr} ${p.currency}\n` +
    `Modalidad: ${p.assignmentMode}\n\n` +
    `Inicia sesión en la app Continente Conecta para participar.\n\n— Continente Cargo`;

  const html = `
    <div style="font-family:sans-serif;max-width:480px;color:#1a1a2e;">
      <h2 style="color:${p.isUrgent ? "#dc3545" : "#0057B8"};">
        ${p.isUrgent ? "🚨 ¡Carga urgente!" : "¡Nueva carga disponible!"}
      </h2>
      ${urgentBanner}
      <p>Hola <strong>${p.firstName}</strong>,</p>
      <table style="width:100%;border-collapse:collapse;">
        <tr><td style="padding:5px 0;color:#555;">Referencia</td>
            <td style="padding:5px 0;font-weight:bold;">${p.reference}</td></tr>
        <tr><td style="padding:5px 0;color:#555;">Ruta</td>
            <td style="padding:5px 0;font-weight:bold;">${p.origin} → ${p.destination}</td></tr>
        ${p.pickupDateStr ? `<tr><td style="padding:5px 0;color:#555;">Posicionamiento</td>
            <td style="padding:5px 0;font-weight:bold;">${p.pickupDateStr}</td></tr>` : ""}
        <tr><td style="padding:5px 0;color:#555;">Equipo</td>
            <td style="padding:5px 0;">${p.equipment}</td></tr>
        <tr><td style="padding:5px 0;color:#555;">Unidades</td>
            <td style="padding:5px 0;">${p.unitCount}</td></tr>
        <tr><td style="padding:5px 0;color:#555;">Precio</td>
            <td style="padding:5px 0;font-weight:bold;color:${p.isUrgent ? "#dc3545" : "#0057B8"};">
              $${p.priceStr} ${p.currency}
            </td></tr>
        <tr><td style="padding:5px 0;color:#555;">Modalidad</td>
            <td style="padding:5px 0;">${p.assignmentMode}</td></tr>
      </table>
      <p>Inicia sesión en la app <strong>Continente Conecta</strong> para participar.</p>
      <br/><p style="color:#888;font-size:12px;">— Continente Cargo</p>
    </div>`;

  return { from, to, subject, text, html };
}

export function buildAssignedMailOptions(
  firstName: string,
  reference: string,
  origin: string,
  destination: string,
  tarifa: number | null,
  moneda: string,
  to: string,
  from: string
): nodemailer.SendMailOptions {
  const tarifaLine = tarifa != null
    ? `Tarifa acordada: $${tarifa.toLocaleString("es-MX")} ${moneda} + IVA\n`
    : "";
  const tarifaHtml = tarifa != null
    ? `<p>Tarifa acordada: <strong>$${tarifa.toLocaleString("es-MX")} ${moneda} + IVA</strong></p>`
    : "";
  return {
    from,
    to,
    subject: `¡Carga asignada! ${reference}`,
    text:
      `Hola ${firstName},\n\nSe te ha asignado el viaje ${reference} (${origin} → ${destination}) ` +
      `en la plataforma Continente Conecta.\n${tarifaLine}` +
      `\nInicia sesión en la app para ver todos los detalles.\n\n— Continente Cargo`,
    html: `
      <div style="font-family:sans-serif;max-width:480px;color:#1a1a2e;">
        <h2 style="color:#0057B8;">¡Carga asignada!</h2>
        <p>Hola <strong>${firstName}</strong>,</p>
        <p>Se te ha asignado el viaje <strong>${reference}</strong><br/>
           Ruta: <strong>${origin} → ${destination}</strong></p>
        ${tarifaHtml}
        <p>Inicia sesión en la app <strong>Continente Conecta</strong> para ver todos los detalles.</p>
        <br/><p style="color:#888;font-size:13px;">— Continente Cargo</p>
      </div>`,
  };
}

export function buildOfferMailOptions(
  adminFirstName: string,
  carrierName: string,
  reference: string,
  amountStr: string,
  currency: string,
  to: string,
  from: string
): nodemailer.SendMailOptions {
  return {
    from,
    to,
    subject: `Nueva oferta en ${reference} — ${carrierName}`,
    text:
      `Hola ${adminFirstName},\n\n${carrierName} envió una oferta de $${amountStr} ${currency} ` +
      `sobre la carga ${reference}.\n\nRevisa las ofertas en Continente Conecta.\n\n— Continente Cargo`,
    html: `
      <div style="font-family:sans-serif;max-width:480px;color:#1a1a2e;">
        <h2 style="color:#0057B8;">Nueva oferta recibida</h2>
        <p>Hola <strong>${adminFirstName}</strong>,</p>
        <p><strong>${carrierName}</strong> ha enviado una oferta sobre la carga <strong>${reference}</strong>.</p>
        <p style="font-size:1.2em;font-weight:bold;color:#0057B8;">$${amountStr} ${currency}</p>
        <p>Revisa las ofertas en la app <strong>Continente Conecta</strong>.</p>
        <br/><p style="color:#888;font-size:12px;">— Continente Cargo</p>
      </div>`,
  };
}

export function buildCounterOfferAdminMailOptions(
  adminFirstName: string,
  carrierName: string,
  reference: string,
  proposedStr: string,
  publishedStr: string,
  currency: string,
  unitCount: number,
  to: string,
  from: string
): nodemailer.SendMailOptions {
  return {
    from,
    to,
    subject: `Contra-oferta pendiente: ${reference} — ${carrierName}`,
    text:
      `Hola ${adminFirstName},\n\n` +
      `${carrierName} propuso un precio diferente al publicado en la carga ${reference}.\n\n` +
      `Precio publicado: $${publishedStr} ${currency}\n` +
      `Precio propuesto: $${proposedStr} ${currency} (por unidad) · ${unitCount} unidades\n\n` +
      `Abre la app Continente Conecta para aprobar o rechazar la propuesta.\n\n— Continente Cargo`,
    html: `
      <div style="font-family:sans-serif;max-width:480px;color:#1a1a2e;">
        <h2 style="color:#e87800;">Contra-oferta pendiente de aprobación</h2>
        <p>Hola <strong>${adminFirstName}</strong>,</p>
        <p><strong>${carrierName}</strong> propuso un precio diferente para la carga <strong>${reference}</strong>.</p>
        <table style="width:100%;border-collapse:collapse;margin:8px 0;">
          <tr><td style="padding:5px 0;color:#555;">Precio publicado</td>
              <td style="padding:5px 0;font-weight:bold;">$${publishedStr} ${currency}</td></tr>
          <tr><td style="padding:5px 0;color:#555;">Precio propuesto</td>
              <td style="padding:5px 0;font-weight:bold;color:#e87800;">$${proposedStr} ${currency} / unidad</td></tr>
          <tr><td style="padding:5px 0;color:#555;">Unidades</td>
              <td style="padding:5px 0;">${unitCount}</td></tr>
        </table>
        <p>Abre la app <strong>Continente Conecta</strong> para aprobar o rechazar.</p>
        <br/><p style="color:#888;font-size:12px;">— Continente Cargo</p>
      </div>`,
  };
}

export function buildCounterOfferApprovedMailOptions(
  carrierFirstName: string,
  reference: string,
  proposedStr: string,
  currency: string,
  to: string,
  from: string
): nodemailer.SendMailOptions {
  return {
    from,
    to,
    subject: `¡Propuesta aprobada! ${reference}`,
    text:
      `Hola ${carrierFirstName},\n\n` +
      `Tu propuesta de precio de $${proposedStr} ${currency} (sin IVA) para la carga ` +
      `${reference} fue aprobada por el administrador.\n\n` +
      `Se te ha asignado el viaje. Abre la app para ver los detalles.\n\n— Continente Cargo`,
    html: `
      <div style="font-family:sans-serif;max-width:480px;color:#1a1a2e;">
        <h2 style="color:#28a745;">¡Propuesta aprobada! ✅</h2>
        <p>Hola <strong>${carrierFirstName}</strong>,</p>
        <p>Tu propuesta de precio para la carga <strong>${reference}</strong> fue aprobada.</p>
        <p style="font-size:1.1em;">
          Precio acordado: <strong style="color:#0057B8;">$${proposedStr} ${currency} s/IVA</strong>
        </p>
        <p>Abre la app <strong>Continente Conecta</strong> para ver los detalles del viaje.</p>
        <br/><p style="color:#888;font-size:12px;">— Continente Cargo</p>
      </div>`,
  };
}

export function buildCounterOfferRejectedMailOptions(
  carrierFirstName: string,
  reference: string,
  to: string,
  from: string
): nodemailer.SendMailOptions {
  return {
    from,
    to,
    subject: `Propuesta no aprobada — ${reference}`,
    text:
      `Hola ${carrierFirstName},\n\n` +
      `Tu propuesta de precio para la carga ${reference} no fue aprobada en esta ocasión.\n\n` +
      `Si tienes dudas, contáctanos directamente.\n\n— Continente Cargo`,
    html: `
      <div style="font-family:sans-serif;max-width:480px;color:#1a1a2e;">
        <h2 style="color:#555;">Propuesta no aprobada</h2>
        <p>Hola <strong>${carrierFirstName}</strong>,</p>
        <p>Tu propuesta de precio para la carga <strong>${reference}</strong> no fue aprobada.</p>
        <p>Para más información contáctanos directamente.</p>
        <br/><p style="color:#888;font-size:12px;">— Continente Cargo</p>
      </div>`,
  };
}

export function buildAdminLoadPublishedOptions(
  adminEmail: string,
  reference: string,
  origin: string,
  destination: string,
  equipment: string,
  priceStr: string,
  currency: string,
  carriersNotified: number,
  from: string
): nodemailer.SendMailOptions {
  const subject = `Carga publicada: ${reference} — ${origin} → ${destination}`;
  const text =
    `Tu carga ${reference} fue publicada correctamente.\n\n` +
    `Ruta: ${origin} → ${destination}\n` +
    `Equipo: ${equipment}\n` +
    `Precio ofrecido: $${priceStr} ${currency}\n` +
    `Transportistas notificados: ${carriersNotified}\n\n— Continente Cargo`;

  const html = `<div style="font-family:sans-serif;max-width:520px;color:#1a1a2e;">
    <h2 style="color:#0057B8;">Carga publicada ✅</h2>
    <table style="border-collapse:collapse;width:100%;margin-top:8px;">
      <tr><td style="padding:6px 0;color:#555;width:150px;">Referencia</td><td style="padding:6px 0;font-weight:bold;">${reference}</td></tr>
      <tr><td style="padding:6px 0;color:#555;">Ruta</td><td style="padding:6px 0;">${origin} → ${destination}</td></tr>
      <tr><td style="padding:6px 0;color:#555;">Equipo</td><td style="padding:6px 0;">${equipment}</td></tr>
      <tr><td style="padding:6px 0;color:#555;">Precio</td><td style="padding:6px 0;font-weight:bold;color:#0057B8;">$${priceStr} ${currency}</td></tr>
      <tr><td style="padding:6px 0;color:#555;">Transportistas</td><td style="padding:6px 0;">${carriersNotified} notificados</td></tr>
    </table>
    <br/><p style="color:#888;font-size:12px;">— Continente Cargo</p>
  </div>`;

  return { from, to: adminEmail, subject, text, html };
}

export function buildStatusMailOptions(
  firstName: string,
  email: string,
  isApproved: boolean,
  from: string
): nodemailer.SendMailOptions {
  const subject = isApproved
    ? "¡Tu cuenta en Continente Conecta fue aprobada!"
    : "Actualización sobre tu solicitud en Continente Conecta";

  const text = isApproved
    ? `¡Felicidades ${firstName}!\n\nTu cuenta en Continente Conecta fue aprobada. ` +
      `Ya puedes iniciar sesión con tu correo: ${email}\n\n` +
      `Si no recuerdas tu contraseña, usa "¿Olvidé mi contraseña?" en la app.\n\n— Continente Cargo`
    : `Hola ${firstName},\n\nLamentamos informarte que tu solicitud de registro ` +
      `no fue aprobada en esta ocasión. Para más información contáctanos.\n\n— Continente Cargo`;

  const html = isApproved
    ? `<div style="font-family:sans-serif;max-width:480px;color:#1a1a2e;">
         <h2 style="color:#0057B8;">¡Cuenta aprobada! ✅</h2>
         <p>Hola <strong>${firstName}</strong>,</p>
         <p>Tu cuenta en <strong>Continente Conecta</strong> fue aprobada.</p>
         <p>Inicia sesión con: <strong>${email}</strong></p>
         <p style="color:#555;font-size:13px;">
           Si no recuerdas tu contraseña, usa "¿Olvidé mi contraseña?" en la app.
         </p>
         <br/><p style="color:#888;font-size:12px;">— Continente Cargo</p>
       </div>`
    : `<div style="font-family:sans-serif;max-width:480px;color:#1a1a2e;">
         <h2 style="color:#555;">Actualización de tu solicitud</h2>
         <p>Hola <strong>${firstName}</strong>,</p>
         <p>Tu solicitud de registro en <strong>Continente Conecta</strong> no fue aprobada.</p>
         <p>Para más información contáctanos directamente.</p>
         <br/><p style="color:#888;font-size:12px;">— Continente Cargo</p>
       </div>`;

  return { from, to: email, subject, text, html };
}

// ─── Invitation email ─────────────────────────────────────────────────────────

export function buildInvitationMailOptions(
  firstName: string,
  to: string,
  from: string,
  phone?: string,
  registrationUrl?: string  // enlace a la web de registro — agregar cuando esté lista
): nodemailer.SendMailOptions {
  const subject = "Te invitamos a Continente Conecta — Plataforma de transporte";

  const ctaText = registrationUrl
    ? `Ya preparamos tu perfil con los datos que tenemos. Entra a este enlace, ` +
      `revísalos y completa solo lo que falta, incluida tu contraseña:\n${registrationUrl}`
    : `Descarga la app Continente Conecta y crea tu cuenta gratuita.`;

  const text =
    `Hola ${firstName},\n\n` +
    `Continente Cargo te invita a unirte a Continente Conecta, la plataforma digital de gestión de carga.\n\n` +
    `Como transportista registrado podrás:\n` +
    `  • Recibir alertas de cargas disponibles en tus rutas\n` +
    `  • Aceptar viajes y ver el detalle de cada carga\n` +
    `  • Participar en subastas de flete\n` +
    `  • Registrar tus unidades y disponibilidad\n\n` +
    ctaText + `\n\n` +
    `¿Dudas? Escríbenos a operaciones@continentecargo.com\n\n` +
    `— Continente Cargo`;

  const ctaBlock = registrationUrl
    ? `<div style="text-align:center;margin:28px 0;">
         <a href="${registrationUrl}"
            style="background:#0057B8;color:white;text-decoration:none;
                   padding:14px 32px;border-radius:8px;font-size:16px;
                   font-weight:bold;display:inline-block;">
           Completar mi registro →
         </a>
       </div>`
    : `<div style="background:#f0f6ff;border-radius:8px;padding:14px 18px;margin:20px 0;">
         <p style="margin:0;font-weight:600;color:#0057B8;">Cómo empezar:</p>
         <p style="margin:6px 0 0;color:#374151;font-size:14px;">
           Descarga la app <strong>Continente Conecta</strong> y crea tu cuenta con este correo.
         </p>
       </div>`;

  const html =
    `<div style="font-family:sans-serif;max-width:520px;color:#1a1a2e;">
       <div style="background:#0057B8;padding:20px 24px;border-radius:10px 10px 0 0;">
         <h2 style="color:white;margin:0;">Continente Conecta</h2>
         <p style="color:#cce0ff;margin:4px 0 0;">Plataforma de transporte de carga</p>
       </div>
       <div style="background:#fff;padding:24px;border:1px solid #e5e7eb;border-top:none;border-radius:0 0 10px 10px;">
         <p>Hola <strong>${firstName}</strong>,</p>
         <p><strong>Continente Cargo</strong> te invita a unirte a <strong>Continente Conecta</strong>,
            la plataforma digital para gestión de carga terrestre.</p>
         ${registrationUrl
           ? `<p>Ya preparamos tu perfil con los datos que tenemos.
                Revisa la información y completa solo lo que falta, incluida tu contraseña.</p>`
           : ""}
         <p>Como transportista registrado podrás:</p>
         <ul style="padding-left:20px;color:#374151;">
           <li>Recibir alertas de cargas disponibles en tus rutas</li>
           <li>Aceptar viajes y ver el detalle de cada carga</li>
           <li>Participar en subastas de flete</li>
           <li>Registrar tus unidades y disponibilidad</li>
         </ul>
         ${ctaBlock}
         <p style="color:#6b7280;font-size:13px;">¿Dudas? Escríbenos a
           <a href="mailto:operaciones@continentecargo.com" style="color:#0057B8;">operaciones@continentecargo.com</a>
         </p>
         <p style="color:#9ca3af;font-size:12px;margin-top:24px;">— Continente Cargo</p>
       </div>
     </div>`;

  return { from, to, subject, text, html };
}
