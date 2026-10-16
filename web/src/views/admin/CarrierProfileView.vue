<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import {
  carrierProfileError,
  demoCarrierProfile,
  fetchCarrierProfile,
  saveCarrierProfile,
  saveDemoCarrierProfile,
  type CarrierProfile,
  type CarrierProfileDraft,
} from '@/lib/directory';
import { EQUIPMENT_TYPES, MEXICAN_ZONES } from '@/lib/models';
import PageHeader from '@/components/PageHeader.vue';
import EmptyState from '@/components/EmptyState.vue';
import { toast } from '@/lib/toast';
import { UserX } from '@lucide/vue';

const route = useRoute();
const auth = useAuthStore();

const loading = ref(true);
const saving = ref(false);
const missing = ref(false);
const blocked = ref(false);
const phone = ref('');
const status = ref('');
const original = ref('');
const draft = ref<CarrierProfileDraft>(emptyDraft());

const isDemo = computed(() => auth.currentUser?.email === 'demo@continente.local');
const directoryRoute = computed(() =>
  auth.currentUser?.role === 'admin' ? 'admin-directory' : 'pricer-directory',
);
const dirty = computed(() => JSON.stringify(draft.value) !== original.value);
const equipmentOptions = computed(() =>
  unique([...EQUIPMENT_TYPES], draft.value.equipmentTypes),
);
const zoneOptions = computed(() =>
  unique(
    MEXICAN_ZONES.map((zone) => zone.id),
    draft.value.coverageZones,
  ),
);

function emptyDraft(): CarrierProfileDraft {
  return {
    companyName: '',
    contactName: '',
    email: '',
    baseCity: '',
    equipmentTypes: [],
    coverageZones: [],
    handlesLTL: false,
    handlesLocal: false,
    handlesIntraState: false,
    coversUSA: false,
  };
}

function unique(base: readonly string[], extra: string[]) {
  return [...new Set([...base, ...extra])];
}

function snapshot(profile: CarrierProfile): CarrierProfileDraft {
  return {
    companyName: profile.companyName,
    contactName: profile.contactName,
    email: profile.email,
    baseCity: profile.baseCity,
    equipmentTypes: [...profile.equipmentTypes],
    coverageZones: [...profile.coverageZones],
    handlesLTL: profile.handlesLTL,
    handlesLocal: profile.handlesLocal,
    handlesIntraState: profile.handlesIntraState,
    coversUSA: profile.coversUSA,
  };
}

function apply(profile: CarrierProfile) {
  phone.value = profile.phone;
  status.value = profile.status;
  const next = snapshot(profile);
  draft.value = next;
  original.value = JSON.stringify(next);
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

function toggle(list: string[], value: string) {
  const index = list.indexOf(value);
  if (index >= 0) list.splice(index, 1);
  else list.push(value);
}

const statusLabel = computed(() => {
  if (status.value === 'sent') return 'Invitación enviada';
  if (status.value === 'failed') return 'La invitación no llegó';
  if (status.value === 'registered') return 'Figura como registrado';
  return 'Por enviar';
});

async function save() {
  const error = carrierProfileError(draft.value);
  if (error) {
    toast.error(error);
    return;
  }
  saving.value = true;
  const id = String(route.params.id || '');
  try {
    if (isDemo.value) saveDemoCarrierProfile(id, draft.value);
    else await saveCarrierProfile(id, draft.value);
    original.value = JSON.stringify(draft.value);
    toast.success('Perfil actualizado', 'La ficha del transportista quedó guardada.');
  } catch (err) {
    toast.error('No se pudo guardar', err instanceof Error ? err.message : undefined);
  } finally {
    saving.value = false;
  }
}

watch(() => route.params.id, load, { immediate: true });
</script>

<template>
  <div class="cc-page-narrow">
    <PageHeader
      title="Perfil del transportista"
      subtitle="Revisa sus datos y su configuración. Cámbialos si hace falta corregir la ficha."
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
      <EmptyState
        title="Transportista no encontrado"
        subtitle="La ficha no está en el directorio."
      >
        <template #icon><UserX /></template>
      </EmptyState>
    </div>

    <form v-else class="space-y-4" @submit.prevent="save">
      <section class="cc-card p-5">
        <div class="flex flex-wrap items-center justify-between gap-2">
          <h2 class="cc-h2">Perfil</h2>
          <span class="cc-badge bg-slate-100 text-slate-600">{{ statusLabel }}</span>
        </div>
        <div class="mt-4 space-y-4">
          <div>
            <label class="cc-label" for="carrier-company">Empresa</label>
            <input id="carrier-company" v-model="draft.companyName" class="cc-field" maxlength="120" required />
          </div>
          <div>
            <label class="cc-label" for="carrier-contact">Contacto</label>
            <input id="carrier-contact" v-model="draft.contactName" class="cc-field" maxlength="80" autocomplete="name" />
          </div>
          <div>
            <label class="cc-label" for="carrier-email">Correo</label>
            <input id="carrier-email" v-model="draft.email" type="email" class="cc-field" maxlength="120" autocomplete="email" />
          </div>
          <div>
            <label class="cc-label" for="carrier-city">Ciudad base</label>
            <input id="carrier-city" v-model="draft.baseCity" class="cc-field" maxlength="80" />
          </div>
          <div>
            <label class="cc-label" for="carrier-phone">Teléfono</label>
            <input id="carrier-phone" :value="phone" class="cc-field disabled:bg-background disabled:text-muted" disabled />
            <p class="cc-hint">Este número identifica la ficha y no se cambia aquí.</p>
          </div>
        </div>
      </section>

      <section class="cc-card p-5">
        <h2 class="cc-h2">Configuración</h2>
        <p class="mt-0.5 text-[13px] text-muted">
          Equipo, zonas y tipo de servicio. Así queda cómo opera este transportista.
        </p>

        <p class="mb-2 mt-4 text-xs font-medium text-muted">Equipo</p>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="eq in equipmentOptions"
            :key="eq"
            type="button"
            class="cc-chip h-8 text-[12.5px]"
            :class="draft.equipmentTypes.includes(eq) && 'cc-chip-active'"
            @click="toggle(draft.equipmentTypes, eq)"
          >
            {{ eq }}
          </button>
        </div>

        <p class="mb-2 mt-4 text-xs font-medium text-muted">Zonas</p>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="zone in zoneOptions"
            :key="zone"
            type="button"
            class="cc-chip h-8 text-[12.5px]"
            :class="draft.coverageZones.includes(zone) && 'cc-chip-active'"
            @click="toggle(draft.coverageZones, zone)"
          >
            {{ zone }}
          </button>
        </div>

        <div class="mt-4 space-y-2">
          <label class="cc-check">
            <input v-model="draft.handlesLTL" type="checkbox" />
            Opera carga consolidada (LTL)
          </label>
          <label class="cc-check">
            <input v-model="draft.handlesLocal" type="checkbox" />
            Opera servicio local
          </label>
          <label class="cc-check">
            <input v-model="draft.handlesIntraState" type="checkbox" />
            Opera dentro del mismo estado
          </label>
          <label class="cc-check">
            <input v-model="draft.coversUSA" type="checkbox" />
            Cubre Estados Unidos
          </label>
        </div>
      </section>

      <button type="submit" class="cc-btn sm:w-auto" :disabled="saving || !dirty">
        {{ saving ? 'Guardando…' : 'Guardar perfil' }}
      </button>
    </form>
  </div>
</template>
