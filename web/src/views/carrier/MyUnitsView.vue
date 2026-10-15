<script setup lang="ts">
import { computed, ref } from 'vue';
import { Car, Plus } from '@lucide/vue';
import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';
import EmptyState from '@/components/EmptyState.vue';
import {
  EQUIPMENT_TYPES,
  MEXICAN_STATES,
  UNIT_STATUSES,
  newUuid,
  type EquipmentType,
  type Unit,
  type UnitStatus,
} from '@/lib/models';
import { formatShortDate, unitStatusClass } from '@/lib/format';

const auth = useAuthStore();
const store = useDataStore();

const showForm = ref(false);
const editingId = ref<string | null>(null);
const busy = ref(false);

const equipmentType = ref<EquipmentType>("Caja Seca 53'");
const plates = ref('');
const trailerNumber = ref('');
const currentLocation = ref('N.L.');
const operatorName = ref('');
const scac = ref('');
const caat = ref('');
const notes = ref('');
const status = ref<UnitStatus>('Disponible');

const units = computed(() =>
  store.myUnits().filter((u) => u.notes !== 'availability_post'),
);

function resetForm() {
  editingId.value = null;
  equipmentType.value = "Caja Seca 53'";
  plates.value = '';
  trailerNumber.value = '';
  currentLocation.value = 'N.L.';
  operatorName.value = '';
  scac.value = '';
  caat.value = '';
  notes.value = '';
  status.value = 'Disponible';
}

function startAdd() {
  resetForm();
  showForm.value = true;
}

function startEdit(unit: Unit) {
  editingId.value = unit.id;
  equipmentType.value = unit.equipmentType;
  plates.value = unit.plates;
  trailerNumber.value = unit.trailerNumber;
  currentLocation.value = unit.currentLocation || 'N.L.';
  operatorName.value = unit.operatorName;
  scac.value = unit.scac;
  caat.value = unit.caat;
  notes.value = unit.notes;
  status.value = unit.status;
  showForm.value = true;
}

async function save() {
  if (!auth.currentUser) return;
  busy.value = true;
  try {
    const base: Unit = {
      id: editingId.value ?? newUuid(),
      ownerId: auth.currentUser.companyId ?? auth.currentUser.uuid,
      equipmentType: equipmentType.value,
      plates: plates.value.trim(),
      trailerNumber: trailerNumber.value.trim(),
      currentLocation: currentLocation.value,
      operatorName: operatorName.value.trim(),
      scac: scac.value.trim(),
      caat: caat.value.trim(),
      availableFrom: new Date(),
      coverageZones: [],
      status: status.value,
      notes: notes.value.trim(),
      postedOriginState: '',
      postedDestinationState: '',
      isAvailabilityPosted: false,
    };
    if (editingId.value) {
      const existing = store.units.find((u) => u.id === editingId.value);
      if (existing) {
        base.availableFrom = existing.availableFrom;
        base.postedOriginState = existing.postedOriginState;
        base.postedDestinationState = existing.postedDestinationState;
        base.isAvailabilityPosted = existing.isAvailabilityPosted;
        base.operatorId = existing.operatorId;
      }
      await store.updateUnit(base);
    } else {
      await store.addUnit(base);
    }
    showForm.value = false;
    resetForm();
  } finally {
    busy.value = false;
  }
}

async function remove(id: string) {
  if (!confirm('¿Eliminar esta unidad?')) return;
  await store.deleteUnit(id);
}

async function setStatus(id: string, st: UnitStatus) {
  await store.updateUnitStatus(id, st);
}
</script>

<template>
  <div class="mx-auto max-w-5xl px-4 py-5 md:px-6">
    <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-xl font-bold text-navy">Mis unidades</h1>
        <p class="text-sm text-muted">Flota y disponibilidad</p>
      </div>
      <button
        type="button"
        class="inline-flex h-10 items-center gap-2 rounded-[10px] bg-brand px-4 text-sm font-semibold text-white"
        @click="startAdd"
      >
        <Plus class="size-4" />
        Agregar
      </button>
    </div>

    <div v-if="showForm" class="mb-5 rounded-2xl border border-line bg-card p-4 space-y-3">
      <h2 class="text-sm font-semibold text-navy">
        {{ editingId ? 'Editar unidad' : 'Nueva unidad' }}
      </h2>
      <div class="grid gap-3 sm:grid-cols-2">
        <div>
          <label class="cc-label">Tipo de equipo</label>
          <select v-model="equipmentType" class="cc-field">
            <option v-for="e in EQUIPMENT_TYPES" :key="e" :value="e">{{ e }}</option>
          </select>
        </div>
        <div>
          <label class="cc-label">Estado</label>
          <select v-model="status" class="cc-field">
            <option v-for="s in UNIT_STATUSES" :key="s" :value="s">{{ s }}</option>
          </select>
        </div>
        <div>
          <label class="cc-label">Placas</label>
          <input v-model="plates" class="cc-field" />
        </div>
        <div>
          <label class="cc-label">Número de caja</label>
          <input v-model="trailerNumber" class="cc-field" />
        </div>
        <div>
          <label class="cc-label">Ubicación actual</label>
          <select v-model="currentLocation" class="cc-field">
            <option v-for="s in MEXICAN_STATES" :key="s" :value="s">{{ s }}</option>
          </select>
        </div>
        <div>
          <label class="cc-label">Operador</label>
          <input v-model="operatorName" class="cc-field" />
        </div>
        <div>
          <label class="cc-label">SCAC</label>
          <input v-model="scac" class="cc-field" />
        </div>
        <div>
          <label class="cc-label">CAAT</label>
          <input v-model="caat" class="cc-field" />
        </div>
      </div>
      <div>
        <label class="cc-label">Notas</label>
        <input v-model="notes" class="cc-field" />
      </div>
      <div class="flex gap-2">
        <button type="button" class="cc-btn h-10 flex-1 text-sm" :disabled="busy" @click="save">
          {{ busy ? 'Guardando…' : 'Guardar' }}
        </button>
        <button
          type="button"
          class="cc-btn-secondary h-10 flex-1 text-sm"
          @click="
            showForm = false;
            resetForm();
          "
        >
          Cancelar
        </button>
      </div>
    </div>

    <EmptyState
      v-if="!units.length && !showForm"
      title="Sin unidades"
      subtitle="Agrega tu flota para poder tomar cargas de tarifa fija."
    >
      <template #icon><Car class="size-6" /></template>
    </EmptyState>

    <div v-else class="space-y-3">
      <article
        v-for="unit in units"
        :key="unit.id"
        class="rounded-2xl border border-line bg-card p-4"
      >
        <div class="flex flex-wrap items-start justify-between gap-2">
          <div>
            <p class="font-semibold text-navy">
              {{ unit.plates || unit.trailerNumber || 'Sin placas' }}
            </p>
            <p class="text-sm text-muted">{{ unit.equipmentType }}</p>
            <p class="mt-1 text-xs text-muted">
              {{ unit.currentLocation || 'Sin ubicación' }}
              <span v-if="unit.operatorName"> · {{ unit.operatorName }}</span>
              · Disponible desde {{ formatShortDate(unit.availableFrom) }}
            </p>
          </div>
          <span
            class="rounded-full px-2.5 py-0.5 text-[11px] font-semibold"
            :class="unitStatusClass(unit.status)"
          >
            {{ unit.status }}
          </span>
        </div>
        <div class="mt-3 flex flex-wrap gap-2">
          <button
            type="button"
            class="rounded-lg border border-line px-2.5 py-1 text-xs font-medium text-navy"
            @click="startEdit(unit)"
          >
            Editar
          </button>
          <button
            v-for="st in UNIT_STATUSES"
            :key="st"
            type="button"
            class="rounded-lg border border-line px-2.5 py-1 text-xs font-medium text-muted hover:text-navy"
            :class="unit.status === st ? 'border-brand text-brand' : ''"
            @click="setStatus(unit.id, st)"
          >
            {{ st }}
          </button>
          <button
            type="button"
            class="rounded-lg border border-danger/30 px-2.5 py-1 text-xs font-medium text-danger"
            @click="remove(unit.id)"
          >
            Eliminar
          </button>
        </div>
      </article>
    </div>
  </div>
</template>
