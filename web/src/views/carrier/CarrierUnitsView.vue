<script setup lang="ts">
import { reactive, ref } from 'vue';
import StatusBadge from '@/components/StatusBadge.vue';
import EmptyState from '@/components/EmptyState.vue';
import { useDataStore } from '@/stores/data';
import { useAuthStore } from '@/stores/auth';
import {
  EQUIPMENT_TYPES,
  MEXICAN_STATES,
  newUuid,
  type EquipmentType,
  type Unit,
  type UnitStatus,
} from '@/lib/models';
import { formatDate } from '@/lib/format';

const store = useDataStore();
const auth = useAuthStore();
const showForm = ref(false);
const form = reactive({
  equipmentType: EQUIPMENT_TYPES[0] as EquipmentType,
  plates: '',
  trailerNumber: '',
  operatorName: '',
  scac: '',
  caat: '',
  currentLocation: 'N.L.',
  availableFrom: new Date().toISOString().slice(0, 10),
  status: 'Disponible' as UnitStatus,
  notes: '',
});

async function save() {
  if (!auth.currentUser) return;
  const unit: Unit = {
    id: newUuid(),
    ownerId: auth.currentUser.uuid,
    equipmentType: form.equipmentType,
    plates: form.plates,
    trailerNumber: form.trailerNumber,
    currentLocation: form.currentLocation,
    operatorName: form.operatorName,
    scac: form.scac,
    caat: form.caat,
    availableFrom: new Date(form.availableFrom),
    coverageZones: [],
    status: form.status,
    notes: form.notes,
    postedOriginState: '',
    postedDestinationState: '',
    isAvailabilityPosted: false,
  };
  await store.addUnit(unit);
  showForm.value = false;
}
</script>

<template>
  <div class="mx-auto w-full max-w-3xl px-4 py-6 sm:px-6">
    <div class="flex items-end justify-between">
      <h1 class="text-2xl font-bold text-navy">Mis unidades</h1>
      <button type="button" class="text-sm font-semibold text-blue" @click="showForm = !showForm">
        {{ showForm ? 'Cerrar' : 'Agregar' }}
      </button>
    </div>

    <form
      v-if="showForm"
      class="mt-4 space-y-2 rounded-2xl border border-line bg-card p-4"
      @submit.prevent="save"
    >
      <select v-model="form.equipmentType" class="cc-field">
        <option v-for="e in EQUIPMENT_TYPES" :key="e" :value="e">{{ e }}</option>
      </select>
      <input v-model="form.plates" class="cc-field" placeholder="Placas" />
      <input v-model="form.trailerNumber" class="cc-field" placeholder="No. remolque / caja" />
      <input v-model="form.operatorName" class="cc-field" placeholder="Operador" />
      <div class="grid grid-cols-2 gap-2">
        <input v-model="form.scac" class="cc-field" placeholder="SCAC" />
        <input v-model="form.caat" class="cc-field" placeholder="CAAT" />
      </div>
      <select v-model="form.currentLocation" class="cc-field">
        <option v-for="s in MEXICAN_STATES" :key="s" :value="s">{{ s }}</option>
      </select>
      <input v-model="form.availableFrom" type="date" class="cc-field" />
      <button type="submit" class="cc-btn">Guardar unidad</button>
    </form>

    <div class="mt-5 space-y-3">
      <div
        v-for="u in store.myUnits()"
        :key="u.id"
        class="rounded-2xl border border-line bg-card p-4"
      >
        <div class="flex justify-between gap-2">
          <div>
            <p class="font-semibold text-navy">{{ u.equipmentType }}</p>
            <p class="text-xs text-muted">
              {{ u.plates || 'Sin placas' }} · {{ u.trailerNumber || '—' }}
            </p>
            <p class="text-xs text-muted">
              {{ u.currentLocation }} · desde {{ formatDate(u.availableFrom) }}
            </p>
          </div>
          <StatusBadge :status="u.status" />
        </div>
        <button
          type="button"
          class="mt-2 text-xs font-semibold text-danger"
          @click="store.deleteUnit(u.id)"
        >
          Eliminar
        </button>
      </div>
      <EmptyState v-if="!store.myUnits().length" title="Sin unidades registradas" />
    </div>
  </div>
</template>
