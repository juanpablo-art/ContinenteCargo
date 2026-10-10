<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import {
  EQUIPMENT_TYPES,
  MEXICAN_ZONES,
  newUuid,
  type CarrierRoute,
  type EquipmentType,
  type UserRole,
} from '@/lib/models';

type RegType = 'carrier' | 'independent_operator';
type Step = 'basic' | 'coverage' | 'done';
type CoverageMode = 'zone' | 'route';

const auth = useAuthStore();
const router = useRouter();

const step = ref<Step>('basic');
const name = ref('');
const email = ref('');
const phone = ref('');
const password = ref('');
const selectedType = ref<RegType>('carrier');
const companyName = ref('');
const companyContact = ref('');
const handlesLTL = ref(false);

const coverageMode = ref<CoverageMode>('zone');
/** Individual states — matches iOS MexicoZoneMapView.selectedStates. */
const selectedStates = ref<Set<string>>(new Set());
const coverageEquipment = ref<Set<EquipmentType>>(new Set());
const routes = ref<CarrierRoute[]>([]);
const originState = ref('N.L.');
const destinationState = ref('CDMX');
const bidirectional = ref(true);
const routeEquipment = ref<Set<EquipmentType>>(new Set());
const finishEquipmentError = ref(false);

const allStates = MEXICAN_ZONES.flatMap((z) => [...z.states]);

const basicValid = computed(() => {
  const companyReady =
    selectedType.value !== 'carrier' ||
    (companyName.value.trim() !== '' && companyContact.value.trim() !== '');
  return (
    name.value.trim() !== '' &&
    email.value.trim() !== '' &&
    phone.value.trim() !== '' &&
    password.value !== '' &&
    companyReady
  );
});

type ZoneLevel = 'none' | 'partial' | 'full';

function zoneSelectionLevel(zone: (typeof MEXICAN_ZONES)[number]): ZoneLevel {
  const selected = zone.states.filter((s) => selectedStates.value.has(s)).length;
  if (selected === 0) return 'none';
  if (selected === zone.states.length) return 'full';
  return 'partial';
}

function selectedCountInZone(zone: (typeof MEXICAN_ZONES)[number]): number {
  return zone.states.filter((s) => selectedStates.value.has(s)).length;
}

/** Zones that still have at least one selected state (for chip grouping). */
const zonesWithSelectedStates = computed(() =>
  MEXICAN_ZONES.filter((z) => z.states.some((s) => selectedStates.value.has(s))).map(
    (z) => ({
      id: z.id,
      states: z.states.filter((s) => selectedStates.value.has(s)),
    }),
  ),
);

const canFinish = computed(() => {
  if (coverageMode.value === 'zone') return selectedStates.value.size > 0;
  return routes.value.length > 0;
});

/** Tap zone: full → clear all; else add all missing states (iOS toggleZone). */
function toggleZone(zoneId: string) {
  const zone = MEXICAN_ZONES.find((z) => z.id === zoneId);
  if (!zone) return;
  const next = new Set(selectedStates.value);
  if (zoneSelectionLevel(zone) === 'full') {
    zone.states.forEach((s) => next.delete(s));
  } else {
    zone.states.forEach((s) => next.add(s));
  }
  selectedStates.value = next;
}

function removeState(state: string) {
  const next = new Set(selectedStates.value);
  next.delete(state);
  selectedStates.value = next;
}

function toggleEquipment(set: Set<EquipmentType>, eq: EquipmentType) {
  const next = new Set(set);
  if (next.has(eq)) next.delete(eq);
  else next.add(eq);
  return next;
}

function toggleCoverageEquipment(eq: EquipmentType) {
  coverageEquipment.value = toggleEquipment(coverageEquipment.value, eq);
  if (coverageEquipment.value.size) finishEquipmentError.value = false;
}

function toggleRouteEquipment(eq: EquipmentType) {
  routeEquipment.value = toggleEquipment(routeEquipment.value, eq);
}

function addRoute() {
  if (!routeEquipment.value.size) return;
  if (
    routes.value.some(
      (r) =>
        r.originState === originState.value &&
        r.destinationState === destinationState.value,
    )
  ) {
    return;
  }
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
  routes.value = routes.value.filter((r) => r.id !== id);
}

async function submit() {
  if (coverageMode.value === 'zone' && !coverageEquipment.value.size) {
    finishEquipmentError.value = true;
    return;
  }
  auth.clearError();
  const role = selectedType.value as Exclude<UserRole, 'admin'>;
  const ok = await auth.register({
    name: name.value.trim(),
    email: email.value.trim(),
    password: password.value,
    phone: phone.value.trim(),
    role,
    companyName: companyName.value.trim(),
    companyContact: companyContact.value.trim(),
    routes: coverageMode.value === 'route' ? routes.value : [],
    coverageStates:
      coverageMode.value === 'zone' ? [...selectedStates.value] : [],
    coverageEquipmentTypes:
      coverageMode.value === 'zone' ? [...coverageEquipment.value] : [],
    handlesLTL: selectedType.value === 'carrier' ? handlesLTL.value : false,
  });
  if (ok) step.value = 'done';
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
        type="button"
        class="text-sm font-medium text-blue"
        @click="step === 'coverage' ? (step = 'basic') : goLogin()"
      >
        {{ step === 'coverage' ? 'Atrás' : step === 'done' ? '' : 'Cancelar' }}
      </button>
      <h1 class="text-sm font-semibold text-navy">
        {{ step === 'done' ? 'Registro' : step === 'coverage' ? 'Cobertura y equipo' : 'Registro' }}
      </h1>
      <span class="w-16" />
    </header>

    <!-- Success -->
    <div
      v-if="step === 'done'"
      class="mx-auto flex max-w-md flex-col items-center px-6 py-16 text-center"
    >
      <div
        class="mb-6 flex size-20 items-center justify-center rounded-full bg-orange-soft text-orange"
      >
        <svg class="size-10" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="1.75"
            d="M12 6v6l4 2m6-2a10 10 0 11-20 0 10 10 0 0120 0z"
          />
        </svg>
      </div>
      <h2 class="text-xl font-bold text-navy">Registro enviado</h2>
      <p class="mt-3 text-sm leading-relaxed text-muted">
        Tu solicitud fue recibida. El equipo de Continente Cargo la revisará y
        recibirás una notificación con la respuesta.
      </p>
      <button type="button" class="cc-btn mt-8 max-w-xs" @click="goLogin">
        Entendido
      </button>
    </div>

    <!-- Step 1 -->
    <form
      v-else-if="step === 'basic'"
      class="mx-auto max-w-md space-y-5 px-5 py-6"
      @submit.prevent="step = 'coverage'"
    >
      <div class="flex items-center gap-2 text-xs text-muted">
        <span class="size-2 rounded-full bg-blue" />
        <span class="h-0.5 w-8 bg-blue" />
        <span class="size-2 rounded-full bg-line" />
        <span class="ml-auto">Paso 1 de 2</span>
      </div>

      <div>
        <p class="cc-label">Tipo de cuenta</p>
        <div class="grid grid-cols-2 gap-2">
          <button
            type="button"
            class="rounded-[10px] border px-3 py-3 text-left text-sm transition"
            :class="
              selectedType === 'carrier'
                ? 'border-blue bg-blue-soft text-navy'
                : 'border-line bg-card text-muted'
            "
            @click="selectedType = 'carrier'"
          >
            <span class="block font-semibold">Línea Transportista</span>
          </button>
          <button
            type="button"
            class="rounded-[10px] border px-3 py-3 text-left text-sm transition"
            :class="
              selectedType === 'independent_operator'
                ? 'border-blue bg-blue-soft text-navy'
                : 'border-line bg-card text-muted'
            "
            @click="selectedType = 'independent_operator'"
          >
            <span class="block font-semibold">Operador Independiente</span>
          </button>
        </div>
      </div>

      <div>
        <label class="cc-label" for="name">Nombre completo</label>
        <input id="name" v-model="name" required class="cc-field" />
      </div>
      <div>
        <label class="cc-label" for="reg-email">Correo electrónico</label>
        <input
          id="reg-email"
          v-model="email"
          type="email"
          required
          autocomplete="email"
          class="cc-field"
        />
      </div>
      <div>
        <label class="cc-label" for="phone">Teléfono</label>
        <input
          id="phone"
          v-model="phone"
          type="tel"
          required
          autocomplete="tel"
          class="cc-field"
        />
      </div>
      <div>
        <label class="cc-label" for="reg-password">Contraseña</label>
        <input
          id="reg-password"
          v-model="password"
          type="password"
          required
          minlength="6"
          autocomplete="new-password"
          class="cc-field"
        />
      </div>

      <template v-if="selectedType === 'carrier'">
        <div class="h-px bg-line" />
        <h3 class="font-semibold text-navy">Datos de la empresa</h3>
        <div>
          <label class="cc-label" for="company">Nombre de la empresa</label>
          <input id="company" v-model="companyName" class="cc-field" />
        </div>
        <div>
          <label class="cc-label" for="contact">Persona de contacto</label>
          <input id="contact" v-model="companyContact" class="cc-field" />
        </div>
        <label class="flex items-start gap-3 rounded-[10px] border border-line bg-card p-3">
          <input v-model="handlesLTL" type="checkbox" class="mt-1 accent-blue" />
          <span>
            <span class="block text-sm font-medium text-ink">
              Manejo carga consolidada (LTL)
            </span>
            <span class="text-xs text-muted">
              Acepto cargas parciales que se agrupan con otros envíos
            </span>
          </span>
        </label>
      </template>

      <button type="submit" class="cc-btn" :disabled="!basicValid">
        Siguiente: Rutas y equipo
      </button>
    </form>

    <!-- Step 2 -->
    <div v-else class="mx-auto max-w-md space-y-5 px-5 py-6 pb-28">
      <div class="flex items-center gap-2 text-xs text-muted">
        <span class="size-2 rounded-full bg-blue" />
        <span class="h-0.5 w-8 bg-blue" />
        <span class="size-2 rounded-full bg-blue" />
        <span class="ml-auto">Paso 2 de 2</span>
      </div>

      <div class="grid grid-cols-2 gap-1 rounded-xl bg-line/60 p-1">
        <button
          type="button"
          class="rounded-lg px-3 py-2 text-sm font-semibold transition"
          :class="coverageMode === 'zone' ? 'bg-card text-navy shadow-sm' : 'text-muted'"
          @click="coverageMode = 'zone'"
        >
          Por Zona
        </button>
        <button
          type="button"
          class="rounded-lg px-3 py-2 text-sm font-semibold transition"
          :class="coverageMode === 'route' ? 'bg-card text-navy shadow-sm' : 'text-muted'"
          @click="coverageMode = 'route'"
        >
          Por Ruta
        </button>
      </div>

      <!-- Zone mode -->
      <div v-if="coverageMode === 'zone'" class="space-y-4">
        <p class="text-sm text-muted">
          Toca una zona para agregar sus estados. Luego quita los que no corras.
        </p>
        <div class="grid gap-2">
          <button
            v-for="zone in MEXICAN_ZONES"
            :key="zone.id"
            type="button"
            class="rounded-[10px] border px-3 py-3 text-left transition"
            :class="{
              'border-line bg-card': zoneSelectionLevel(zone) === 'none',
              'border-blue/60 bg-blue-soft/50': zoneSelectionLevel(zone) === 'partial',
              'border-blue bg-blue-soft': zoneSelectionLevel(zone) === 'full',
            }"
            @click="toggleZone(zone.id)"
          >
            <span class="flex items-center justify-between gap-2">
              <span class="text-sm font-semibold text-navy">{{ zone.id }}</span>
              <span
                v-if="zoneSelectionLevel(zone) !== 'none'"
                class="rounded-full bg-blue/15 px-2 py-0.5 text-[10px] font-bold text-blue-ink"
              >
                {{ selectedCountInZone(zone) }}/{{ zone.states.length }}
              </span>
            </span>
            <span class="mt-0.5 block text-xs text-muted">{{ zone.states.join(', ') }}</span>
          </button>
        </div>

        <div v-if="selectedStates.size > 0" class="space-y-2">
          <p class="text-[11px] text-muted">
            Estados seleccionados — toca × para quitar uno
          </p>
          <div
            v-for="group in zonesWithSelectedStates"
            :key="group.id"
            class="flex flex-wrap items-center gap-1.5"
          >
            <span
              class="rounded-full bg-navy/10 px-2 py-0.5 text-[10px] font-bold text-navy"
            >
              {{ group.id }}
            </span>
            <button
              v-for="state in group.states"
              :key="state"
              type="button"
              class="inline-flex items-center gap-1 rounded-full bg-blue-soft px-2.5 py-1 text-[11px] font-medium text-blue-ink ring-1 ring-inset ring-blue/25"
              :aria-label="`Quitar ${state}`"
              @click="removeState(state)"
            >
              {{ state }}
              <span class="text-[10px] font-bold opacity-70" aria-hidden="true">×</span>
            </button>
          </div>
        </div>

        <div>
          <p
            class="cc-label"
            :class="finishEquipmentError ? 'text-danger' : ''"
          >
            Equipo que opero *
          </p>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="eq in EQUIPMENT_TYPES"
              :key="eq"
              type="button"
              class="rounded-full border px-3 py-1.5 text-xs font-medium transition"
              :class="
                coverageEquipment.has(eq)
                  ? 'border-blue bg-blue text-white'
                  : 'border-line bg-card text-ink'
              "
              @click="toggleCoverageEquipment(eq)"
            >
              {{ eq }}
            </button>
          </div>
          <p v-if="finishEquipmentError" class="mt-2 text-xs text-danger">
            Selecciona el equipo que operas antes de solicitar el registro
          </p>
        </div>
      </div>

      <!-- Route mode -->
      <div v-else class="space-y-4">
        <div>
          <h3 class="font-semibold text-navy">Agrega las rutas que corres</h3>
          <p class="text-xs text-muted">
            Define origen, destino y el tipo de unidades que manejas en cada ruta.
          </p>
        </div>

        <div class="space-y-3 rounded-2xl border border-line bg-card p-4">
          <div class="grid grid-cols-2 gap-2">
            <div>
              <label class="cc-label">Origen</label>
              <select v-model="originState" class="cc-field">
                <option v-for="s in allStates" :key="'o-' + s" :value="s">
                  {{ s }}
                </option>
              </select>
            </div>
            <div>
              <label class="cc-label">Destino</label>
              <select v-model="destinationState" class="cc-field">
                <option v-for="s in allStates" :key="'d-' + s" :value="s">
                  {{ s }}
                </option>
              </select>
            </div>
          </div>

          <label class="flex items-center gap-2 text-sm text-ink">
            <input v-model="bidirectional" type="checkbox" class="accent-blue" />
            Bidireccional
          </label>

          <div>
            <p class="cc-label">Tipo de unidad *</p>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="eq in EQUIPMENT_TYPES"
                :key="'r-' + eq"
                type="button"
                class="rounded-full border px-3 py-1.5 text-xs font-medium transition"
                :class="
                  routeEquipment.has(eq)
                    ? 'border-blue bg-blue text-white'
                    : 'border-line bg-card text-ink'
                "
                @click="toggleRouteEquipment(eq)"
              >
                {{ eq }}
              </button>
            </div>
          </div>

          <button
            type="button"
            class="cc-btn-secondary h-10 text-sm"
            :disabled="!routeEquipment.size"
            @click="addRoute"
          >
            Agregar ruta
          </button>
        </div>

        <ul v-if="routes.length" class="space-y-2">
          <li
            v-for="r in routes"
            :key="r.id"
            class="flex items-start justify-between gap-3 rounded-[10px] border border-line bg-card px-3 py-3"
          >
            <div>
              <p class="text-sm font-semibold text-navy">
                {{ r.originState }}
                {{ r.bidirectional ? '↔' : '→' }}
                {{ r.destinationState }}
              </p>
              <p class="text-xs text-muted">{{ r.equipmentTypes.join(', ') }}</p>
            </div>
            <button
              type="button"
              class="text-xs font-medium text-danger"
              @click="removeRoute(r.id)"
            >
              Quitar
            </button>
          </li>
        </ul>
        <p v-else class="py-6 text-center text-sm text-muted">
          Aún no has agregado rutas
        </p>
      </div>

      <p v-if="auth.errorMessage" class="text-center text-xs text-danger">
        {{ auth.errorMessage }}
      </p>

      <div class="fixed inset-x-0 bottom-0 border-t border-line bg-card/95 p-4 backdrop-blur">
        <div class="mx-auto max-w-md">
          <button
            type="button"
            class="cc-btn"
            :disabled="!canFinish || auth.isLoading"
            @click="submit"
          >
            <span
              v-if="auth.isLoading"
              class="mr-2 size-4 animate-spin rounded-full border-2 border-white/30 border-t-white"
            />
            Solicitar registro
          </button>
          <p v-if="!canFinish" class="mt-2 text-center text-xs text-muted">
            {{
              coverageMode === 'zone'
                ? 'Selecciona al menos un estado para continuar'
                : 'Agrega al menos una ruta para continuar'
            }}
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
