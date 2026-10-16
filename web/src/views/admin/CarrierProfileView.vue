<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { CircleAlert, Mail, MessageCircle, Plus, Trash2, UserX, X } from '@lucide/vue';
import { useAuthStore } from '@/stores/auth';
import {
  carrierProfileError,
  demoCarrierProfile,
  fetchCarrierProfile,
  saveCarrierProfile,
  saveDemoCarrierProfile,
  zonesFromStates,
  type CarrierProfile,
  type CarrierProfileDraft,
} from '@/lib/directory';
import {
  EQUIPMENT_TYPES,
  MEXICAN_STATES,
  newUuid,
  type CarrierRoute,
  type EquipmentType,
} from '@/lib/models';
import {
  checkWhatsApp,
  isValidEmail,
  normalizeWhatsapp,
  whatsappStatus,
} from '@/lib/registration';
import FormSwitch from '@/components/FormSwitch.vue';
import MexicoZoneMap from '@/components/MexicoZoneMap.vue';
import USAZoneGrid from '@/components/USAZoneGrid.vue';
import PageHeader from '@/components/PageHeader.vue';
import EmptyState from '@/components/EmptyState.vue';
import { toast } from '@/lib/toast';

type CoverageMode = 'zone' | 'route';

const route = useRoute();
const auth = useAuthStore();

const loading = ref(true);
const saving = ref(false);
const missing = ref(false);
const blocked = ref(false);
const phone = ref('');
const status = ref('');
const original = ref('');
const coverageMode = ref<CoverageMode>('zone');
const draft = ref<CarrierProfileDraft>(emptyDraft());

const originState = ref('N.L.');
const destinationState = ref('CDMX');
const bidirectional = ref(true);
const routeEquipment = ref<Set<EquipmentType>>(new Set());
const routeEquipmentError = ref(false);
const newEmailInput = ref('');
const newWhatsappInput = ref('');
const isCheckingWhatsApp = ref(false);
const whatsappCheckError = ref('');

const isDemo = computed(() => auth.currentUser?.email === 'demo@continente.local');
const directoryRoute = computed(() =>
  auth.currentUser?.role === 'admin' ? 'admin-directory' : 'pricer-directory',
);
const emailReady = computed(() => isValidEmail(newEmailInput.value.trim()));
const pendingWhatsappStatus = computed(() => whatsappStatus(newWhatsappInput.value));
const selectedStates = computed({
  get: () => new Set(draft.value.coverageStates),
  set: (value: Set<string>) => {
    draft.value.coverageStates = [...value];
  },
});
const selectedUsaStates = computed({
  get: () => new Set(draft.value.coverageUSAStates),
  set: (value: Set<string>) => {
    draft.value.coverageUSAStates = [...value];
  },
});
const alreadyAdded = computed(() =>
  draft.value.routes.some(
    (item) => item.originState === originState.value && item.destinationState === destinationState.value,
  ),
);
const canAddRoute = computed(
  () => routeEquipment.value.size > 0 && !alreadyAdded.value && draft.value.routes.length < 12,
);
const addRouteLabel = computed(() => {
  if (alreadyAdded.value) return 'Ruta ya agregada';
  if (canAddRoute.value) return 'Agregar esta ruta';
  if (draft.value.routes.length >= 12) return 'Máximo 12 rutas';
  return 'Selecciona el equipo para agregar';
});
const dirty = computed(() => JSON.stringify(currentPayload()) !== original.value);

function emptyDraft(): CarrierProfileDraft {
  return {
    name: '',
    companyName: '',
    contactName: '',
    email: '',
    baseCity: '',
    equipmentTypes: [],
    coverageZones: [],
    coverageStates: [],
    handlesLTL: false,
    handlesLocal: false,
    handlesIntraState: false,
    coversUSA: false,
    coverageUSAStates: [],
    routes: [],
    notificationEmails: [],
    whatsappNumbers: [],
  };
}

function isEquipment(value: string): value is EquipmentType {
  return (EQUIPMENT_TYPES as readonly string[]).includes(value);
}

function currentPayload(): CarrierProfileDraft {
  const person = draft.value.name.trim();
  const contact = draft.value.contactName.trim() || person;
  const shared = {
    ...draft.value,
    name: person || contact,
    contactName: contact,
    email: draft.value.email.trim(),
    companyName: draft.value.companyName.trim(),
    baseCity: draft.value.baseCity.trim(),
    coverageUSAStates: draft.value.coversUSA ? [...draft.value.coverageUSAStates] : [],
    notificationEmails: [...draft.value.notificationEmails],
    whatsappNumbers: [...draft.value.whatsappNumbers],
  };
  if (coverageMode.value === 'route') {
    const equipment = [...new Set(draft.value.routes.flatMap((item) => item.equipmentTypes))];
    return {
      ...shared,
      coverageStates: [],
      coverageZones: [],
      routes: draft.value.routes.map((item) => ({ ...item, equipmentTypes: [...item.equipmentTypes] })),
      equipmentTypes: equipment.length ? equipment : [...draft.value.equipmentTypes],
    };
  }
  return {
    ...shared,
    coverageStates: [...draft.value.coverageStates],
    coverageZones: zonesFromStates(draft.value.coverageStates),
    routes: [],
    equipmentTypes: [...draft.value.equipmentTypes],
  };
}

function apply(profile: CarrierProfile) {
  phone.value = profile.phone;
  status.value = profile.status;
  coverageMode.value = profile.routes.length && !profile.coverageStates.length ? 'route' : 'zone';
  draft.value = {
    name: profile.name,
    companyName: profile.companyName,
    contactName: profile.contactName,
    email: profile.email,
    baseCity: profile.baseCity,
    equipmentTypes: [...profile.equipmentTypes],
    coverageZones: [...profile.coverageZones],
    coverageStates: [...profile.coverageStates],
    handlesLTL: profile.handlesLTL,
    handlesLocal: profile.handlesLocal,
    handlesIntraState: profile.handlesIntraState,
    coversUSA: profile.coversUSA,
    coverageUSAStates: [...profile.coverageUSAStates],
    routes: profile.routes.map((item) => ({ ...item, equipmentTypes: [...item.equipmentTypes] })),
    notificationEmails: [...profile.notificationEmails],
    whatsappNumbers: [...profile.whatsappNumbers],
  };
  original.value = JSON.stringify(currentPayload());
}

function ownedBySomeoneElse(profile: CarrierProfile) {
  if (auth.currentUser?.role !== 'pricer') return false;
  const owner = profile.pricerEmail.trim().toLowerCase();
  const mine = (auth.currentUser.email ?? '').trim().toLowerCase();
  return Boolean(owner) && owner !== mine;
}

async function load() {
  loading.value = true;
  missing.value = false;
  blocked.value = false;
  const id = String(route.params.id || '');
  try {
    const profile = isDemo.value ? demoCarrierProfile(id) : await fetchCarrierProfile(id);
    if (!profile) {
      missing.value = true;
      return;
    }
    if (ownedBySomeoneElse(profile)) {
      blocked.value = true;
      return;
    }
    apply(profile);
  } catch (err) {
    missing.value = true;
    toast.error('No se pudo abrir el perfil', err instanceof Error ? err.message : undefined);
  } finally {
    loading.value = false;
  }
}

function toggleEquipment(eq: EquipmentType) {
  const list = draft.value.equipmentTypes;
  const index = list.indexOf(eq);
  if (index >= 0) list.splice(index, 1);
  else list.push(eq);
}

function toggleRouteEquipment(eq: EquipmentType) {
  const next = new Set(routeEquipment.value);
  if (next.has(eq)) next.delete(eq);
  else next.add(eq);
  routeEquipment.value = next;
  if (next.size) routeEquipmentError.value = false;
}

function addRoute() {
  if (!routeEquipment.value.size) {
    routeEquipmentError.value = true;
    return;
  }
  if (alreadyAdded.value || draft.value.routes.length >= 12) return;
  const routeItem: CarrierRoute = {
    id: newUuid(),
    originState: originState.value,
    destinationState: destinationState.value,
    bidirectional: bidirectional.value,
    equipmentTypes: [...routeEquipment.value],
  };
  draft.value.routes = [...draft.value.routes, routeItem];
}

function removeRoute(id: string) {
  draft.value.routes = draft.value.routes.filter((item) => item.id !== id);
}

function addEmail() {
  const trimmed = newEmailInput.value.trim().toLowerCase();
  if (!isValidEmail(trimmed) || draft.value.notificationEmails.includes(trimmed)) return;
  if (trimmed === draft.value.email.trim().toLowerCase()) return;
  if (draft.value.notificationEmails.length >= 10) return;
  draft.value.notificationEmails = [...draft.value.notificationEmails, trimmed];
  newEmailInput.value = '';
}

function removeEmail(index: number) {
  draft.value.notificationEmails = draft.value.notificationEmails.filter((_, i) => i !== index);
}

async function addWhatsapp() {
  const digits = normalizeWhatsapp(newWhatsappInput.value);
  if (pendingWhatsappStatus.value !== 'valid' || draft.value.whatsappNumbers.includes(digits)) return;
  if (draft.value.whatsappNumbers.length >= 10) return;
  isCheckingWhatsApp.value = true;
  whatsappCheckError.value = '';
  const result = isDemo.value ? true : await checkWhatsApp(digits);
  isCheckingWhatsApp.value = false;
  if (result === false) {
    whatsappCheckError.value = 'Este número no tiene WhatsApp instalado';
    return;
  }
  draft.value.whatsappNumbers = [...draft.value.whatsappNumbers, digits];
  newWhatsappInput.value = '';
}

function removeWhatsapp(index: number) {
  draft.value.whatsappNumbers = draft.value.whatsappNumbers.filter((_, i) => i !== index);
}

const statusLabel = computed(() => {
  if (status.value === 'sent') return 'Invitación enviada';
  if (status.value === 'failed') return 'La invitación no llegó';
  if (status.value === 'registered') return 'Figura como registrado';
  return 'Por enviar';
});

async function save() {
  const payload = currentPayload();
  const error = carrierProfileError(payload);
  if (error) {
    toast.error(error);
    return;
  }
  saving.value = true;
  const id = String(route.params.id || '');
  try {
    if (isDemo.value) saveDemoCarrierProfile(id, payload);
    else await saveCarrierProfile(id, payload);
    draft.value = {
      ...payload,
      equipmentTypes: [...payload.equipmentTypes],
      coverageStates: [...payload.coverageStates],
      coverageZones: [...payload.coverageZones],
      coverageUSAStates: [...payload.coverageUSAStates],
      routes: payload.routes.map((item) => ({ ...item, equipmentTypes: [...item.equipmentTypes] })),
      notificationEmails: [...payload.notificationEmails],
      whatsappNumbers: [...payload.whatsappNumbers],
    };
    original.value = JSON.stringify(currentPayload());
    toast.success('Perfil actualizado', 'La ficha del transportista quedó guardada.');
  } catch (err) {
    toast.error('No se pudo guardar', err instanceof Error ? err.message : undefined);
  } finally {
    saving.value = false;
  }
}

watch(newWhatsappInput, () => {
  whatsappCheckError.value = '';
});

watch(() => route.params.id, load, { immediate: true });
</script>

<template>
  <div class="cc-page-narrow">
    <PageHeader
      title="Perfil del transportista"
      subtitle="Los mismos datos que llena al registrarse. Corrígelos si hace falta."
      :back="{ name: directoryRoute }"
      back-label="Directorio"
    />

    <div v-if="loading" class="cc-card p-8 text-sm text-muted">Cargando perfil…</div>

    <div v-else-if="blocked" class="cc-card">
      <EmptyState
        title="Lo atiende otro pricer"
        subtitle="Esta ficha ya tiene responsable. No puedes ver ni editar su perfil."
      >
        <template #icon><UserX /></template>
      </EmptyState>
    </div>

    <div v-else-if="missing" class="cc-card">
      <EmptyState title="Transportista no encontrado" subtitle="La ficha no está en el directorio.">
        <template #icon><UserX /></template>
      </EmptyState>
    </div>

    <form v-else class="space-y-5" @submit.prevent="save">
      <section class="cc-card space-y-4 p-5">
        <div class="flex flex-wrap items-center justify-between gap-2">
          <h2 class="cc-h2">Datos de contacto</h2>
          <span class="cc-badge bg-slate-100 text-slate-600">{{ statusLabel }}</span>
        </div>
        <div>
          <label class="cc-label" for="carrier-name">Nombre completo</label>
          <input id="carrier-name" v-model="draft.name" autocomplete="name" maxlength="80" class="cc-field" />
        </div>
        <div>
          <label class="cc-label" for="carrier-email">Correo electrónico</label>
          <input id="carrier-email" v-model="draft.email" type="email" autocomplete="email" maxlength="120" class="cc-field" />
        </div>
        <div>
          <label class="cc-label" for="carrier-phone">WhatsApp / Teléfono</label>
          <input id="carrier-phone" :value="phone" class="cc-field disabled:bg-background disabled:text-muted" disabled />
          <p class="cc-hint">Este número identifica la ficha y no se cambia aquí.</p>
        </div>
      </section>

      <section class="cc-card space-y-4 p-5">
        <h2 class="cc-h2">Datos de la empresa</h2>
        <div>
          <label class="cc-label" for="carrier-company">Nombre de la empresa</label>
          <input id="carrier-company" v-model="draft.companyName" autocomplete="organization" maxlength="120" required class="cc-field" />
        </div>
        <div>
          <label class="cc-label" for="carrier-contact">Persona de contacto</label>
          <input id="carrier-contact" v-model="draft.contactName" maxlength="80" class="cc-field" />
        </div>
        <div>
          <label class="cc-label" for="carrier-city">Ciudad base</label>
          <input id="carrier-city" v-model="draft.baseCity" maxlength="80" class="cc-field" />
        </div>
        <FormSwitch
          v-model="draft.handlesLTL"
          title="Manejo carga consolidada (LTL)"
          hint="Acepta cargas parciales que se agrupan con otros envíos"
          label="Manejo carga consolidada (LTL)"
        />
      </section>

      <section class="cc-card space-y-2 p-5">
        <h2 class="cc-h2">Tipo de rutas</h2>
        <FormSwitch
          v-model="draft.handlesLocal"
          title="Opera rutas locales (misma ciudad)"
          hint="Entrega dentro de la misma ciudad o zona metropolitana"
          label="Opera rutas locales"
        />
        <FormSwitch
          v-model="draft.handlesIntraState"
          title="Opera entre ciudades del mismo estado"
          hint="Ej. Monterrey ↔ Linares, Guadalajara ↔ Puerto Vallarta"
          label="Opera entre ciudades del mismo estado"
        />
      </section>

      <section class="cc-card space-y-4 p-5">
        <div>
          <h2 class="cc-h2">Contactos de notificación adicionales</h2>
          <p class="mt-1 text-xs leading-relaxed text-muted">
            El WhatsApp principal ya recibe alertas. Agrega correos o WhatsApp de despachadores, coordinadores o socios.
          </p>
        </div>
        <div class="space-y-2">
          <p class="text-sm font-semibold text-ink">Correos adicionales</p>
          <ul v-if="draft.notificationEmails.length" class="space-y-2">
            <li
              v-for="(item, index) in draft.notificationEmails"
              :key="item"
              class="flex items-center gap-2 rounded-lg border border-line bg-background px-3 py-2.5"
            >
              <Mail class="size-3.5 shrink-0 text-blue" aria-hidden="true" />
              <span class="min-w-0 flex-1 truncate text-sm">{{ item }}</span>
              <button type="button" :aria-label="`Quitar ${item}`" @click="removeEmail(index)">
                <X class="size-4 text-muted" />
              </button>
            </li>
          </ul>
          <div class="flex items-center gap-2 rounded-lg border border-line bg-background px-3 py-1.5">
            <input
              v-model="newEmailInput"
              type="email"
              placeholder="correo@empresa.com"
              autocomplete="off"
              class="min-w-0 flex-1 bg-transparent py-1.5 text-sm outline-none placeholder:text-muted/60"
              @keydown.enter.prevent="addEmail"
            />
            <button type="button" aria-label="Agregar correo" :disabled="!emailReady || draft.notificationEmails.length >= 10" @click="addEmail">
              <Plus class="size-6" :class="emailReady ? 'text-blue' : 'text-muted'" />
            </button>
          </div>
        </div>
        <div class="space-y-2">
          <div>
            <p class="text-sm font-semibold text-ink">WhatsApp adicionales</p>
            <p class="mt-0.5 text-[11px] leading-relaxed text-muted">
              Al agregar un número se verifica que tenga WhatsApp.
            </p>
          </div>
          <ul v-if="draft.whatsappNumbers.length" class="space-y-2">
            <li
              v-for="(item, index) in draft.whatsappNumbers"
              :key="item"
              class="flex items-center gap-2 rounded-lg border border-line bg-background px-3 py-2.5"
            >
              <MessageCircle class="size-3.5 shrink-0 text-success" aria-hidden="true" />
              <span class="min-w-0 flex-1 text-sm">{{ item }}</span>
              <button type="button" :aria-label="`Quitar ${item}`" @click="removeWhatsapp(index)">
                <X class="size-4 text-muted" />
              </button>
            </li>
          </ul>
          <div class="flex items-center gap-2 rounded-lg border border-line bg-background px-3 py-1.5">
            <input
              v-model="newWhatsappInput"
              type="tel"
              inputmode="numeric"
              placeholder="10 dígitos, ej. 8112345678"
              autocomplete="off"
              class="min-w-0 flex-1 bg-transparent py-1.5 text-sm outline-none placeholder:text-muted/60"
              @keydown.enter.prevent="addWhatsapp"
            />
            <button
              type="button"
              aria-label="Agregar WhatsApp"
              :disabled="pendingWhatsappStatus !== 'valid' || isCheckingWhatsApp || draft.whatsappNumbers.length >= 10"
              @click="addWhatsapp"
            >
              <Plus class="size-6" :class="pendingWhatsappStatus === 'valid' ? 'text-success' : 'text-muted'" />
            </button>
          </div>
          <p v-if="whatsappCheckError" class="flex items-center gap-1.5 text-xs text-danger">
            <CircleAlert class="size-3.5 shrink-0" aria-hidden="true" />
            {{ whatsappCheckError }}
          </p>
          <p v-else-if="pendingWhatsappStatus === 'tooShort'" class="flex items-center gap-1.5 text-xs text-danger">
            <CircleAlert class="size-3.5 shrink-0" aria-hidden="true" />
            Número incompleto — se requieren 10 dígitos
          </p>
          <p v-else-if="pendingWhatsappStatus === 'tooLong'" class="flex items-center gap-1.5 text-xs text-danger">
            <CircleAlert class="size-3.5 shrink-0" aria-hidden="true" />
            Número demasiado largo — ingresa solo los 10 dígitos sin código de país
          </p>
        </div>
      </section>

      <section class="cc-card space-y-4 p-5">
        <h2 class="cc-h2">Cobertura y equipo</h2>
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
          <div class="rounded-[10px] border border-line bg-background p-3">
            <p class="cc-label">Equipo que opera</p>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="eq in EQUIPMENT_TYPES"
                :key="eq"
                type="button"
                class="cc-chip h-8 text-xs"
                :class="draft.equipmentTypes.includes(eq) && 'cc-chip-active'"
                :aria-pressed="draft.equipmentTypes.includes(eq)"
                @click="toggleEquipment(eq)"
              >
                {{ eq }}
              </button>
            </div>
          </div>
        </div>

        <div v-else class="space-y-4">
          <section class="space-y-3 rounded-2xl bg-background p-3.5">
            <h3 class="text-sm font-semibold text-navy">Configura la ruta</h3>
            <div class="grid grid-cols-[1fr_auto_1fr] items-end gap-2">
              <div>
                <label class="cc-label" for="carrier-origin">Origen</label>
                <select id="carrier-origin" v-model="originState" class="cc-field">
                  <option v-for="state in MEXICAN_STATES" :key="`o-${state}`" :value="state">{{ state }}</option>
                </select>
              </div>
              <span class="pb-3 text-sm font-semibold text-blue" aria-hidden="true">{{ bidirectional ? '↔' : '→' }}</span>
              <div>
                <label class="cc-label" for="carrier-destination">Destino</label>
                <select id="carrier-destination" v-model="destinationState" class="cc-field">
                  <option v-for="state in MEXICAN_STATES" :key="`d-${state}`" :value="state">{{ state }}</option>
                </select>
              </div>
            </div>
            <FormSwitch
              v-model="bidirectional"
              title="Bidireccional (A → B y B → A)"
              label="Ruta bidireccional"
            />
            <div>
              <p class="cc-label" :class="routeEquipmentError ? 'text-danger' : ''">Tipo de unidad</p>
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
            <button type="button" class="cc-btn" :disabled="!canAddRoute" @click="addRoute">
              <Plus class="size-4" aria-hidden="true" />
              {{ addRouteLabel }}
            </button>
          </section>
          <section class="space-y-3 rounded-2xl bg-background p-3.5">
            <h3 class="text-sm font-semibold text-navy">
              Rutas agregadas
              <span v-if="draft.routes.length" class="text-xs font-medium text-blue">({{ draft.routes.length }})</span>
            </h3>
            <p v-if="!draft.routes.length" class="text-xs text-muted">Configura y agrega las rutas arriba.</p>
            <ul v-else class="overflow-hidden rounded-xl border border-line bg-card">
              <li
                v-for="item in draft.routes"
                :key="item.id"
                class="flex items-center gap-3 border-b border-line px-3.5 py-3 last:border-b-0"
              >
                <div class="min-w-0 flex-1">
                  <p class="text-sm font-semibold text-navy">
                    {{ item.originState }} {{ item.bidirectional ? '↔' : '→' }} {{ item.destinationState }}
                  </p>
                  <p class="text-xs text-muted">{{ item.equipmentTypes.join(', ') || 'Cualquier equipo' }}</p>
                </div>
                <button
                  type="button"
                  class="flex size-8 items-center justify-center rounded-full bg-danger-soft text-danger"
                  :aria-label="`Quitar ruta ${item.originState} ${item.destinationState}`"
                  @click="removeRoute(item.id)"
                >
                  <Trash2 class="size-3.5" />
                </button>
              </li>
            </ul>
          </section>
        </div>

        <div class="h-px bg-line" />
        <h3 class="font-semibold text-navy">Cobertura en Estados Unidos</h3>
        <FormSwitch
          v-model="draft.coversUSA"
          title="También opera en EE.UU."
          hint="Activa para seleccionar sus zonas de cobertura en Estados Unidos."
          label="También opera en EE.UU."
        />
        <USAZoneGrid v-if="draft.coversUSA" v-model="selectedUsaStates" />
      </section>

      <button type="submit" class="cc-btn" :disabled="saving || !dirty">
        {{ saving ? 'Guardando…' : 'Guardar perfil' }}
      </button>
    </form>
  </div>
</template>
