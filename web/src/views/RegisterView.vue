<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import {
  BadgeCheck,
  Building2,
  CircleAlert,
  CircleCheck,
  Clock,
  LoaderCircle,
  Lock,
  Mail,
  MessageCircle,
  Plus,
  Search,
  Trash2,
  User,
  X,
} from '@lucide/vue';
import { useAuthStore } from '@/stores/auth';
import {
  EQUIPMENT_TYPES,
  MEXICAN_STATES,
  MEXICAN_ZONES,
  newUuid,
  type CarrierRoute,
  type EquipmentType,
} from '@/lib/models';
import {
  checkWhatsApp,
  isValidEmail,
  lookupCarrierPreProfile,
  normalizeWhatsapp,
  whatsappStatus,
  type CarrierPreProfile,
} from '@/lib/registration';
import FormSwitch from '@/components/FormSwitch.vue';
import MexicoZoneMap from '@/components/MexicoZoneMap.vue';
import USAZoneGrid from '@/components/USAZoneGrid.vue';

type Step = 'basic' | 'coverage' | 'done';
type CoverageMode = 'zone' | 'route';

const auth = useAuthStore();
const router = useRouter();
const route = useRoute();

function invitePhone(): string {
  const raw = route.query.telefono ?? route.query.phone ?? '';
  const value = Array.isArray(raw) ? raw[0] : raw;
  const digits = String(value ?? '').replace(/\D/g, '');
  const local = digits.startsWith('52') && digits.length === 12 ? digits.slice(2) : digits;
  return /^\d{10}$/.test(local) ? local : '';
}

const step = ref<Step>('basic');
const name = ref('');
const email = ref('');
const phone = ref(invitePhone());
const password = ref('');
const companyName = ref('');
const companyContact = ref('');
const handlesLTL = ref(false);
const handlesLocal = ref(true);
const handlesIntraState = ref(true);

const extraEmails = ref<string[]>([]);
const whatsappNumbers = ref<string[]>([]);
const newEmailInput = ref('');
const newWhatsappInput = ref('');
const isCheckingWhatsApp = ref(false);
const whatsappCheckError = ref('');

const isLookingUpPreProfile = ref(false);
const preProfileFound = ref(false);
let lookupSeq = 0;

const coverageMode = ref<CoverageMode>('zone');
const selectedStates = ref<Set<string>>(new Set());
const coverageEquipment = ref<Set<EquipmentType>>(new Set());
const routes = ref<CarrierRoute[]>([]);
const originState = ref('N.L.');
const destinationState = ref('CDMX');
const bidirectional = ref(true);
const routeEquipment = ref<Set<EquipmentType>>(new Set());
const finishEquipmentError = ref(false);
const routeEquipmentError = ref(false);
const coversUSA = ref(false);
const coverageUSAStates = ref<Set<string>>(new Set());

const phoneDigits = computed(() => phone.value.replace(/\D/g, ''));
const phoneIsValid = computed(() => phoneDigits.value.length === 10);

const basicValid = computed(
  () =>
    name.value.trim() !== '' &&
    email.value.trim() !== '' &&
    password.value !== '' &&
    companyName.value.trim() !== '' &&
    companyContact.value.trim() !== '' &&
    phoneIsValid.value,
);

const emailReady = computed(() => isValidEmail(newEmailInput.value.trim()));
const pendingWhatsappStatus = computed(() => whatsappStatus(newWhatsappInput.value));

const alreadyAdded = computed(() =>
  routes.value.some(
    (route) =>
      route.originState === originState.value &&
      route.destinationState === destinationState.value,
  ),
);

const canAddRoute = computed(
  () => routeEquipment.value.size > 0 && !alreadyAdded.value && routes.value.length < 12,
);

const canFinish = computed(() => {
  if (coverageMode.value === 'zone') return selectedStates.value.size > 0;
  return routes.value.length > 0;
});

const addRouteLabel = computed(() => {
  if (alreadyAdded.value) return 'Ruta ya agregada';
  if (canAddRoute.value) return 'Agregar esta ruta';
  if (routes.value.length >= 12) return 'Máximo 12 rutas';
  return 'Selecciona el equipo para agregar';
});

function isEquipment(value: string): value is EquipmentType {
  return (EQUIPMENT_TYPES as readonly string[]).includes(value);
}

function applyPreProfile(profile: CarrierPreProfile) {
  if (!companyName.value.trim()) companyName.value = profile.companyName;
  if (!companyContact.value.trim()) companyContact.value = profile.contactName;
  if (!email.value.trim()) email.value = profile.email;
  if (!name.value.trim()) name.value = profile.contactName;
  handlesLTL.value = profile.handlesLTL;
  handlesLocal.value = profile.handlesLocal;
  if (typeof profile.handlesIntraState === 'boolean') {
    handlesIntraState.value = profile.handlesIntraState;
  }
  if (typeof profile.coversUSA === 'boolean') coversUSA.value = profile.coversUSA;

  const exactStates = profile.coverageStates.filter((state) =>
    MEXICAN_ZONES.some((zone) => (zone.states as readonly string[]).includes(state)),
  );
  const states = exactStates.length
    ? exactStates
    : profile.coverageZones.flatMap((zoneId) => {
        const zone = MEXICAN_ZONES.find((item) => item.id === zoneId);
        return zone ? [...zone.states] : [];
      });
  if (states.length) selectedStates.value = new Set(states);
  if (profile.coverageUSAStates.length) {
    coverageUSAStates.value = new Set(profile.coverageUSAStates);
  }

  const equipment = profile.equipmentTypes.filter(isEquipment);
  if (equipment.length) coverageEquipment.value = new Set(equipment);
  preProfileFound.value = Boolean(
    profile.companyName.trim() ||
      profile.contactName.trim() ||
      profile.email.trim() ||
      states.length ||
      equipment.length,
  );
}

watch(phoneDigits, async (digits) => {
  preProfileFound.value = false;
  if (digits.length !== 10) {
    isLookingUpPreProfile.value = false;
    return;
  }
  const seq = ++lookupSeq;
  isLookingUpPreProfile.value = true;
  const profile = await lookupCarrierPreProfile(digits);
  if (seq !== lookupSeq) return;
  isLookingUpPreProfile.value = false;
  if (profile) applyPreProfile(profile);
}, { immediate: true });

watch(newWhatsappInput, () => {
  whatsappCheckError.value = '';
});

watch(coverageMode, () => {
  finishEquipmentError.value = false;
});

function toggleCoverageEquipment(eq: EquipmentType) {
  const next = new Set(coverageEquipment.value);
  if (next.has(eq)) next.delete(eq);
  else next.add(eq);
  coverageEquipment.value = next;
  if (next.size) finishEquipmentError.value = false;
}

function toggleRouteEquipment(eq: EquipmentType) {
  const next = new Set(routeEquipment.value);
  if (next.has(eq)) next.delete(eq);
  else next.add(eq);
  routeEquipment.value = next;
  if (next.size) routeEquipmentError.value = false;
}

function addEmail() {
  const trimmed = newEmailInput.value.trim().toLowerCase();
  if (!isValidEmail(trimmed) || extraEmails.value.includes(trimmed)) return;
  if (trimmed === email.value.trim().toLowerCase()) return;
  if (extraEmails.value.length >= 10) return;
  extraEmails.value = [...extraEmails.value, trimmed];
  newEmailInput.value = '';
}

function removeEmail(index: number) {
  extraEmails.value = extraEmails.value.filter((_, i) => i !== index);
}

async function addWhatsapp() {
  const digits = normalizeWhatsapp(newWhatsappInput.value);
  if (pendingWhatsappStatus.value !== 'valid' || whatsappNumbers.value.includes(digits)) return;
  if (whatsappNumbers.value.length >= 10) return;

  isCheckingWhatsApp.value = true;
  whatsappCheckError.value = '';
  const result = await checkWhatsApp(digits);
  isCheckingWhatsApp.value = false;

  if (result === false) {
    whatsappCheckError.value = 'Este número no tiene WhatsApp instalado';
    return;
  }
  whatsappNumbers.value = [...whatsappNumbers.value, digits];
  newWhatsappInput.value = '';
}

function removeWhatsapp(index: number) {
  whatsappNumbers.value = whatsappNumbers.value.filter((_, i) => i !== index);
}

function addRoute() {
  if (!routeEquipment.value.size) {
    routeEquipmentError.value = true;
    return;
  }
  if (alreadyAdded.value || routes.value.length >= 12) return;
  routes.value = [
    ...routes.value,
    {
      id: newUuid(),
      originState: originState.value,
      destinationState: destinationState.value,
      bidirectional: bidirectional.value,
      equipmentTypes: [...routeEquipment.value],
    },
  ];
}

function removeRoute(id: string) {
  routes.value = routes.value.filter((route) => route.id !== id);
}

function goCoverage() {
  if (!basicValid.value) return;
  step.value = 'coverage';
  window.scrollTo({ top: 0 });
}

function goBack() {
  step.value = 'basic';
  window.scrollTo({ top: 0 });
}

async function submit() {
  if (coverageMode.value === 'route' && canAddRoute.value) addRoute();
  if (coverageMode.value === 'zone' && coverageEquipment.value.size === 0) {
    finishEquipmentError.value = true;
    return;
  }
  if (!canFinish.value) return;

  auth.clearError();
  const ok = await auth.register({
    name: name.value.trim(),
    email: email.value.trim(),
    password: password.value,
    phone: phone.value.trim(),
    role: 'carrier',
    companyName: companyName.value.trim(),
    companyContact: companyContact.value.trim(),
    routes: routes.value,
    coverageStates: [...selectedStates.value],
    coverageEquipmentTypes: [...coverageEquipment.value],
    handlesLTL: handlesLTL.value,
    handlesLocal: handlesLocal.value,
    handlesIntraState: handlesIntraState.value,
    coversUSA: coversUSA.value,
    coverageUSAStates: coversUSA.value ? [...coverageUSAStates.value] : [],
    notificationEmails: extraEmails.value,
    whatsappNumbers: whatsappNumbers.value,
  });
  if (ok) {
    step.value = 'done';
    window.scrollTo({ top: 0 });
  }
}

function goLogin() {
  router.push({ name: 'login' });
}
</script>

<template>
  <div class="min-h-dvh bg-background">
    <header
      class="sticky top-0 z-10 flex items-center justify-between border-b border-line bg-card/95 px-4 py-3 backdrop-blur"
    >
      <button
        v-if="step !== 'done'"
        type="button"
        class="text-sm font-medium text-blue"
        @click="step === 'coverage' ? goBack() : goLogin()"
      >
        {{ step === 'coverage' ? 'Atrás' : 'Cancelar' }}
      </button>
      <span v-else class="w-16" />
      <h1 class="text-sm font-semibold text-navy">
        {{ step === 'coverage' ? 'Cobertura y equipo' : 'Registro' }}
      </h1>
      <span class="w-16" />
    </header>

    <div
      v-if="step === 'done'"
      class="mx-auto flex max-w-md flex-col items-center px-6 py-16 text-center"
    >
      <div class="mb-6 flex size-20 items-center justify-center rounded-full bg-orange-soft text-orange">
        <Clock class="size-10" aria-hidden="true" />
      </div>
      <h2 class="text-xl font-bold text-navy">Registro enviado</h2>
      <p class="mt-3 text-sm leading-relaxed text-muted">
        Tu solicitud fue recibida. El equipo de Continente Cargo la revisará y recibirás una
        notificación con la respuesta.
      </p>
      <button type="button" class="cc-btn mt-8 max-w-xs" @click="goLogin">Entendido</button>
    </div>

    <form
      v-else-if="step === 'basic'"
      class="mx-auto max-w-lg space-y-5 px-5 py-6"
      @submit.prevent="goCoverage"
    >
      <div class="flex items-center gap-1.5 text-xs text-muted">
        <span class="size-2 rounded-full bg-blue" />
        <span class="h-0.5 w-8 bg-line" />
        <span class="size-2 rounded-full bg-line" />
        <span class="ml-auto">Paso 1 de 2</span>
      </div>

      <div
        v-if="preProfileFound"
        class="rounded-xl border border-blue/30 bg-blue-soft px-4 py-3 text-sm text-navy"
      >
        <p class="font-semibold">Tu perfil ya está preparado</p>
        <p class="mt-1 text-xs leading-relaxed text-blue-ink">
          Llenamos los datos que ya tenemos de tu invitación. Revísalos, cambia lo que haga
          falta y completa lo que esté vacío. La contraseña no viene incluida.
        </p>
      </div>

      <div>
        <label class="cc-label" for="name">Nombre completo</label>
        <div class="relative">
          <User class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted" />
          <input id="name" v-model="name" autocomplete="name" class="cc-field pl-10" />
        </div>
      </div>

      <div>
        <label class="cc-label" for="reg-email">Correo electrónico</label>
        <div class="relative">
          <Mail class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted" />
          <input
            id="reg-email"
            v-model="email"
            type="email"
            autocomplete="email"
            class="cc-field pl-10"
          />
        </div>
      </div>

      <div>
        <label class="cc-label" for="phone">WhatsApp / Teléfono</label>
        <div class="relative">
          <MessageCircle
            class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted"
          />
          <input
            id="phone"
            v-model="phone"
            type="tel"
            inputmode="numeric"
            autocomplete="tel"
            class="cc-field pl-10"
          />
        </div>
        <p
          v-if="phone && !phoneIsValid"
          class="mt-1.5 flex items-center gap-1.5 text-xs text-danger"
        >
          <CircleAlert class="size-3.5 shrink-0" aria-hidden="true" />
          Se requieren 10 dígitos ({{ phoneDigits.length }}/10)
        </p>
        <p
          v-else-if="phoneIsValid && isLookingUpPreProfile"
          class="mt-1.5 flex items-center gap-1.5 text-xs text-muted"
        >
          <Search class="size-3.5 shrink-0" aria-hidden="true" />
          Buscando tu perfil…
        </p>
        <p
          v-else-if="phoneIsValid && preProfileFound"
          class="mt-1.5 flex items-center gap-1.5 text-xs text-blue"
        >
          <BadgeCheck class="size-3.5 shrink-0" aria-hidden="true" />
          Perfil pre-cargado desde el directorio — revisa y ajusta los datos
        </p>
        <p
          v-else-if="phoneIsValid"
          class="mt-1.5 flex items-center gap-1.5 text-xs text-success"
        >
          <CircleCheck class="size-3.5 shrink-0" aria-hidden="true" />
          Al registrarte recibirás un WhatsApp de confirmación en este número
        </p>
      </div>

      <div>
        <label class="cc-label" for="reg-password">Contraseña</label>
        <div class="relative">
          <Lock class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted" />
          <input
            id="reg-password"
            v-model="password"
            type="password"
            autocomplete="new-password"
            class="cc-field pl-10"
          />
        </div>
        <p v-if="preProfileFound" class="cc-hint">
          Elige una contraseña para iniciar sesión. Este dato no viene en la invitación.
        </p>
      </div>

      <div class="h-px bg-line" />
      <h3 class="font-semibold text-navy">Datos de la empresa</h3>
        <div>
          <label class="cc-label" for="company">Nombre de la empresa</label>
          <div class="relative">
            <Building2
              class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted"
            />
            <input id="company" v-model="companyName" autocomplete="organization" class="cc-field pl-10" />
          </div>
        </div>
        <div>
          <label class="cc-label" for="contact">Persona de contacto</label>
          <div class="relative">
            <User class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted" />
            <input id="contact" v-model="companyContact" class="cc-field pl-10" />
          </div>
        </div>
        <FormSwitch
          v-model="handlesLTL"
          title="Manejo carga consolidada (LTL)"
          hint="Acepto cargas parciales que se agrupan con otros envíos"
          label="Manejo carga consolidada (LTL)"
        />

      <div class="h-px bg-line" />
      <h3 class="font-semibold text-navy">Tipo de rutas</h3>
      <FormSwitch
        v-model="handlesLocal"
        title="Opero rutas locales (misma ciudad)"
        hint="Entrego dentro de la misma ciudad o zona metropolitana"
        label="Opero rutas locales"
      />
      <FormSwitch
        v-model="handlesIntraState"
        title="Opero entre ciudades del mismo estado"
        hint="Ej. Monterrey ↔ Linares, Guadalajara ↔ Puerto Vallarta"
        label="Opero entre ciudades del mismo estado"
      />

      <div class="h-px bg-line" />
      <section class="space-y-4">
        <div>
          <h3 class="font-semibold text-navy">Contactos de notificación adicionales</h3>
          <p class="mt-1 text-xs leading-relaxed text-muted">
            Tu WhatsApp / teléfono ya recibe alertas. Agrega aquí correos o WhatsApp de otros
            contactos (despachadores, coordinadores, socios) que también deban ser notificados.
          </p>
        </div>

        <div class="space-y-2">
          <p class="text-sm font-semibold text-ink">Correos adicionales</p>
          <ul v-if="extraEmails.length" class="space-y-2">
            <li
              v-for="(item, index) in extraEmails"
              :key="item"
              class="flex items-center gap-2 rounded-lg border border-line bg-card px-3 py-2.5"
            >
              <Mail class="size-3.5 shrink-0 text-blue" aria-hidden="true" />
              <span class="min-w-0 flex-1 truncate text-sm">{{ item }}</span>
              <button type="button" :aria-label="`Quitar ${item}`" @click="removeEmail(index)">
                <X class="size-4 text-muted" />
              </button>
            </li>
          </ul>
          <div class="flex items-center gap-2 rounded-lg border border-line bg-card px-3 py-1.5">
            <input
              v-model="newEmailInput"
              type="email"
              placeholder="correo@empresa.com"
              autocomplete="off"
              class="min-w-0 flex-1 bg-transparent py-1.5 text-sm outline-none placeholder:text-muted/60"
              @keydown.enter.prevent="addEmail"
            />
            <button
              type="button"
              aria-label="Agregar correo"
              :disabled="!emailReady || extraEmails.length >= 10"
              @click="addEmail"
            >
              <Plus class="size-6" :class="emailReady ? 'text-blue' : 'text-muted'" />
            </button>
          </div>
        </div>

        <div class="space-y-2">
          <div>
            <p class="text-sm font-semibold text-ink">WhatsApp adicionales</p>
            <p class="mt-0.5 text-[11px] leading-relaxed text-muted">
              Al agregar un número se le envía un mensaje de WhatsApp para verificar que está activo.
            </p>
          </div>
          <ul v-if="whatsappNumbers.length" class="space-y-2">
            <li
              v-for="(item, index) in whatsappNumbers"
              :key="item"
              class="flex items-center gap-2 rounded-lg border border-line bg-card px-3 py-2.5"
            >
              <MessageCircle class="size-3.5 shrink-0 text-success" aria-hidden="true" />
              <span class="min-w-0 flex-1 text-sm">{{ item }}</span>
              <button type="button" :aria-label="`Quitar ${item}`" @click="removeWhatsapp(index)">
                <X class="size-4 text-muted" />
              </button>
            </li>
          </ul>
          <div
            class="rounded-lg border bg-card px-3 py-1.5"
            :class="
              whatsappCheckError ||
              (newWhatsappInput && pendingWhatsappStatus !== 'valid' && pendingWhatsappStatus !== 'empty')
                ? 'border-danger/60'
                : pendingWhatsappStatus === 'valid'
                  ? 'border-success/60'
                  : 'border-line'
            "
          >
            <div class="flex items-center gap-2">
              <input
                v-model="newWhatsappInput"
                type="tel"
                inputmode="numeric"
                placeholder="10 dígitos, ej. 8112345678"
                autocomplete="off"
                class="min-w-0 flex-1 bg-transparent py-1.5 text-sm outline-none placeholder:text-muted/60"
                @keydown.enter.prevent="addWhatsapp"
              />
              <LoaderCircle
                v-if="isCheckingWhatsApp"
                class="size-5 animate-spin text-muted"
                aria-label="Verificando WhatsApp"
              />
              <button
                v-else
                type="button"
                aria-label="Agregar WhatsApp"
                :disabled="pendingWhatsappStatus !== 'valid' || whatsappNumbers.length >= 10"
                @click="addWhatsapp"
              >
                <Plus
                  class="size-6"
                  :class="pendingWhatsappStatus === 'valid' ? 'text-success' : 'text-muted'"
                />
              </button>
            </div>
          </div>
          <p v-if="whatsappCheckError" class="flex items-center gap-1.5 text-xs text-danger">
            <CircleAlert class="size-3.5 shrink-0" aria-hidden="true" />
            {{ whatsappCheckError }}
          </p>
          <p
            v-else-if="pendingWhatsappStatus === 'tooShort'"
            class="flex items-center gap-1.5 text-xs text-danger"
          >
            <CircleAlert class="size-3.5 shrink-0" aria-hidden="true" />
            Número incompleto — se requieren 10 dígitos
          </p>
          <p
            v-else-if="pendingWhatsappStatus === 'tooLong'"
            class="flex items-center gap-1.5 text-xs text-danger"
          >
            <CircleAlert class="size-3.5 shrink-0" aria-hidden="true" />
            Número demasiado largo — ingresa solo los 10 dígitos sin código de país
          </p>
          <p
            v-else-if="pendingWhatsappStatus === 'valid'"
            class="flex items-center gap-1.5 text-xs text-muted"
          >
            <CircleAlert class="size-3.5 shrink-0" aria-hidden="true" />
            Asegúrate de que este número tenga WhatsApp instalado
          </p>
        </div>
      </section>

      <button type="submit" class="cc-btn" :disabled="!basicValid">
        Siguiente: Rutas y equipo
      </button>
    </form>

    <div v-else class="mx-auto max-w-lg space-y-5 px-5 py-6">
      <div class="flex items-center gap-1.5 text-xs text-muted">
        <span class="size-2 rounded-full bg-blue" />
        <span class="h-0.5 w-8 bg-blue" />
        <span class="size-2 rounded-full bg-blue" />
        <span class="ml-auto">Paso 2 de 2</span>
      </div>

      <div class="grid grid-cols-2 gap-1 rounded-xl bg-line/60 p-1" role="tablist">
        <button
          type="button"
          role="tab"
          class="rounded-lg px-3 py-2 text-sm font-semibold transition"
          :class="coverageMode === 'zone' ? 'bg-card text-navy shadow-sm' : 'text-muted'"
          :aria-selected="coverageMode === 'zone'"
          @click="coverageMode = 'zone'"
        >
          Por Zona
        </button>
        <button
          type="button"
          role="tab"
          class="rounded-lg px-3 py-2 text-sm font-semibold transition"
          :class="coverageMode === 'route' ? 'bg-card text-navy shadow-sm' : 'text-muted'"
          :aria-selected="coverageMode === 'route'"
          @click="coverageMode = 'route'"
        >
          Por Ruta
        </button>
      </div>

      <div v-if="coverageMode === 'zone'" class="space-y-4">
        <MexicoZoneMap v-model="selectedStates" />

        <div
          class="rounded-[10px] border bg-card p-3"
          :class="finishEquipmentError ? 'border-danger' : 'border-line'"
        >
          <p class="cc-label" :class="finishEquipmentError ? 'text-danger' : ''">
            Equipo que opero *
          </p>
          <p v-if="!coverageEquipment.size" class="mb-2 text-sm" :class="finishEquipmentError ? 'text-danger' : 'text-muted'">
            Selecciona el tipo de equipo (obligatorio)
          </p>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="eq in EQUIPMENT_TYPES"
              :key="eq"
              type="button"
              class="cc-chip h-8 text-xs"
              :class="coverageEquipment.has(eq) && 'cc-chip-active'"
              :aria-pressed="coverageEquipment.has(eq)"
              @click="toggleCoverageEquipment(eq)"
            >
              {{ eq }}
            </button>
          </div>
          <p v-if="finishEquipmentError" class="mt-2 flex items-start gap-1.5 text-xs text-danger">
            <CircleAlert class="mt-0.5 size-3.5 shrink-0" aria-hidden="true" />
            Selecciona el equipo que operas antes de solicitar el registro
          </p>
        </div>
      </div>

      <div v-else class="space-y-4">
        <section class="space-y-3 rounded-2xl bg-background p-3.5">
          <div class="flex items-center gap-2">
            <span class="flex size-[22px] items-center justify-center rounded-full bg-blue text-[10px] font-bold text-white">
              1
            </span>
            <h3 class="text-sm font-semibold text-navy">Configura la ruta</h3>
          </div>

          <div class="grid grid-cols-[1fr_auto_1fr] items-end gap-2">
            <div>
              <label class="cc-label" for="origin">Origen</label>
              <select id="origin" v-model="originState" class="cc-field">
                <option v-for="state in MEXICAN_STATES" :key="`o-${state}`" :value="state">
                  {{ state }}
                </option>
              </select>
            </div>
            <span class="pb-3 text-sm font-semibold text-blue" aria-hidden="true">
              {{ bidirectional ? '↔' : '→' }}
            </span>
            <div>
              <label class="cc-label" for="destination">Destino</label>
              <select id="destination" v-model="destinationState" class="cc-field">
                <option v-for="state in MEXICAN_STATES" :key="`d-${state}`" :value="state">
                  {{ state }}
                </option>
              </select>
            </div>
          </div>

          <FormSwitch
            v-model="bidirectional"
            title="Bidireccional (A → B y B → A)"
            label="Ruta bidireccional"
          />

          <div>
            <p class="cc-label" :class="routeEquipmentError ? 'text-danger' : ''">
              Tipo de unidad *
            </p>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="eq in EQUIPMENT_TYPES"
                :key="`r-${eq}`"
                type="button"
                class="cc-chip h-8 text-xs"
                :class="routeEquipment.has(eq) && 'cc-chip-active'"
                :aria-pressed="routeEquipment.has(eq)"
                @click="toggleRouteEquipment(eq)"
              >
                {{ eq }}
              </button>
            </div>
            <p v-if="routeEquipmentError" class="mt-2 flex items-center gap-1.5 text-xs text-danger">
              <CircleAlert class="size-3.5 shrink-0" aria-hidden="true" />
              Selecciona el tipo de unidad antes de agregar la ruta
            </p>
          </div>

          <button
            type="button"
            class="text-sm"
            :class="canAddRoute ? 'cc-btn' : 'cc-btn-secondary'"
            :disabled="alreadyAdded || routes.length >= 12"
            @click="addRoute"
          >
            <Plus class="size-4" aria-hidden="true" />
            {{ addRouteLabel }}
          </button>
        </section>

        <section class="space-y-3 rounded-2xl bg-background p-3.5">
          <div class="flex items-center gap-2">
            <span
              class="flex size-[22px] items-center justify-center rounded-full text-[10px] font-bold"
              :class="routes.length ? 'bg-blue text-white' : 'bg-line text-muted'"
            >
              2
            </span>
            <h3 class="text-sm font-semibold" :class="routes.length ? 'text-navy' : 'text-muted'">
              Rutas agregadas
            </h3>
            <span v-if="routes.length" class="text-xs text-blue">({{ routes.length }})</span>
          </div>

          <p v-if="!routes.length" class="py-2 text-xs text-muted">
            Configura y agrega tus rutas arriba
          </p>
          <ul v-else class="overflow-hidden rounded-xl border border-line bg-card">
            <li
              v-for="route in routes"
              :key="route.id"
              class="flex items-center gap-3 border-b border-line px-3.5 py-3 last:border-b-0"
            >
              <div class="min-w-0 flex-1">
                <p class="text-sm font-semibold text-navy">
                  {{ route.originState }}
                  {{ route.bidirectional ? '↔' : '→' }}
                  {{ route.destinationState }}
                </p>
                <p class="text-xs text-muted">{{ route.equipmentTypes.join(', ') }}</p>
              </div>
              <button
                type="button"
                class="flex size-8 items-center justify-center rounded-full bg-danger-soft text-danger"
                :aria-label="`Quitar ruta ${route.originState} ${route.destinationState}`"
                @click="removeRoute(route.id)"
              >
                <Trash2 class="size-3.5" />
              </button>
            </li>
          </ul>
        </section>
      </div>

      <div class="h-px bg-line" />
      <section class="space-y-3">
        <h3 class="font-semibold text-navy">Cobertura en Estados Unidos</h3>
        <FormSwitch
          v-model="coversUSA"
          title="También opero en EE.UU."
          hint="Activa para seleccionar tus zonas de cobertura en Estados Unidos."
          label="También opero en EE.UU."
        />
        <USAZoneGrid v-if="coversUSA" v-model="coverageUSAStates" />
      </section>

      <p
        v-if="auth.errorMessage"
        class="rounded-xl bg-danger-soft px-3 py-2 text-center text-xs text-danger"
      >
        {{ auth.errorMessage }}
      </p>

      <button type="button" class="cc-btn" :disabled="!canFinish || auth.isLoading" @click="submit">
        <LoaderCircle v-if="auth.isLoading" class="size-4 animate-spin" aria-hidden="true" />
        Solicitar registro
      </button>
      <p v-if="!canFinish" class="text-center text-xs text-muted">
        {{
          coverageMode === 'zone'
            ? 'Selecciona al menos una zona para continuar'
            : 'Agrega al menos una ruta para continuar'
        }}
      </p>
    </div>
  </div>
</template>
