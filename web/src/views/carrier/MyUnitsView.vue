<script setup lang="ts">
import { computed, ref } from 'vue';
import { Truck, Plus, Pencil, Trash2, MapPin, UserRound, CalendarDays } from '@lucide/vue';
import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';
import EmptyState from '@/components/EmptyState.vue';
import PageHeader from '@/components/PageHeader.vue';
import SheetModal from '@/components/SheetModal.vue';
import ConfirmModal from '@/components/ConfirmModal.vue';
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
import { toast } from '@/lib/toast';

const auth = useAuthStore();
const store = useDataStore();

const showForm = ref(false);
const editingId = ref<string | null>(null);
const busy = ref(false);
const deleting = ref<Unit | null>(null);

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

const statusDot: Record<UnitStatus, string> = {
  Disponible: 'bg-success',
  Reservada: 'bg-orange',
  'En viaje': 'bg-violet-600',
  'Fuera de servicio': 'bg-slate-400',
};

const counts = computed(() =>
  UNIT_STATUSES.map((s) => ({ status: s, n: units.value.filter((u) => u.status === s).length })),
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

function closeForm() {
  showForm.value = false;
  resetForm();
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
    const isEdit = Boolean(editingId.value);
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
    closeForm();
    toast.success(isEdit ? 'Unidad actualizada' : 'Unidad agregada', base.plates || undefined);
  } catch (e) {
    toast.error('No se pudo guardar', e instanceof Error ? e.message : undefined);
  } finally {
    busy.value = false;
  }
}

async function confirmRemove() {
  const unit = deleting.value;
  deleting.value = null;
  if (!unit) return;
  try {
    await store.deleteUnit(unit.id);
    toast.success('Unidad eliminada');
  } catch (e) {
    toast.error('No se pudo eliminar', e instanceof Error ? e.message : undefined);
  }
}

async function setStatus(id: string, st: UnitStatus) {
  try {
    await store.updateUnitStatus(id, st);
  } catch (e) {
    toast.error('No se pudo cambiar el estado', e instanceof Error ? e.message : undefined);
  }
}
</script>

<template>
  <div class="cc-page">
    <PageHeader title="Mis unidades" :subtitle="`${units.length} unidades en tu flota`">
      <template #actions>
        <button type="button" class="cc-btn w-auto px-5" @click="startAdd">
          <Plus class="size-4" aria-hidden="true" />
          Agregar unidad
        </button>
      </template>
    </PageHeader>

    <div v-if="units.length" class="cc-scroll-x mb-5">
      <span
        v-for="c in counts"
        :key="c.status"
        class="inline-flex shrink-0 items-center gap-2 rounded-full border border-line bg-card px-3 py-1.5 text-[13px] shadow-card"
      >
        <span class="size-2 rounded-full" :class="statusDot[c.status]" />
        <span class="text-muted">{{ c.status }}</span>
        <span class="font-semibold tabular-nums text-navy">{{ c.n }}</span>
      </span>
    </div>

    <div v-if="!units.length" class="cc-card">
      <EmptyState
        title="Aún no tienes unidades"
        subtitle="Agrega tu flota para tomar cargas de tarifa fija y publicar disponibilidad."
      >
        <template #icon><Truck /></template>
        <button type="button" class="cc-btn w-auto px-5" @click="startAdd">
          <Plus class="size-4" aria-hidden="true" /> Agregar unidad
        </button>
      </EmptyState>
    </div>

    <div v-else class="grid gap-3 md:grid-cols-2">
      <article v-for="unit in units" :key="unit.id" class="cc-card flex flex-col p-4 md:p-5">
        <div class="flex items-start gap-3">
          <span class="cc-icon-tile size-11">
            <Truck class="size-5" aria-hidden="true" />
          </span>
          <div class="min-w-0 flex-1">
            <p class="font-mono text-[16px] font-semibold tracking-wide text-navy">
              {{ unit.plates || unit.trailerNumber || 'Sin placas' }}
            </p>
            <p class="text-[13px] text-muted">
              {{ unit.equipmentType }}
              <template v-if="unit.trailerNumber && unit.plates"> · Caja {{ unit.trailerNumber }}</template>
            </p>
          </div>
          <div class="flex shrink-0 gap-1">
            <button
              type="button"
              class="flex size-8 items-center justify-center rounded-lg text-muted transition hover:bg-background hover:text-navy"
              aria-label="Editar unidad"
              @click="startEdit(unit)"
            >
              <Pencil class="size-4" />
            </button>
            <button
              type="button"
              class="flex size-8 items-center justify-center rounded-lg text-muted transition hover:bg-danger-soft hover:text-danger"
              aria-label="Eliminar unidad"
              @click="deleting = unit"
            >
              <Trash2 class="size-4" />
            </button>
          </div>
        </div>

        <dl class="mt-4 grid gap-2 text-[13px] text-ink/80">
          <div class="flex items-center gap-2">
            <MapPin class="size-3.5 text-muted" aria-hidden="true" />
            {{ unit.currentLocation || 'Sin ubicación' }}
          </div>
          <div class="flex items-center gap-2">
            <UserRound class="size-3.5 text-muted" aria-hidden="true" />
            {{ unit.operatorName || 'Sin operador asignado' }}
          </div>
          <div class="flex items-center gap-2">
            <CalendarDays class="size-3.5 text-muted" aria-hidden="true" />
            Disponible desde {{ formatShortDate(unit.availableFrom) }}
          </div>
        </dl>

        <div class="mt-4 border-t border-line pt-3">
          <p class="mb-2 text-[11px] font-semibold uppercase tracking-[0.08em] text-muted">Estado</p>
          <div class="flex flex-wrap gap-1.5">
            <button
              v-for="st in UNIT_STATUSES"
              :key="st"
              type="button"
              class="cc-badge border px-3 py-1 transition"
              :class="
                unit.status === st
                  ? [unitStatusClass(st), 'border-transparent']
                  : 'border-line bg-card font-medium text-muted hover:text-navy'
              "
              @click="unit.status !== st && setStatus(unit.id, st)"
            >
              {{ st }}
            </button>
          </div>
        </div>
      </article>
    </div>

    <SheetModal
      :open="showForm"
      :title="editingId ? 'Editar unidad' : 'Nueva unidad'"
      subtitle="Los datos se comparten con Continente Cargo al asignarte un viaje."
      @close="closeForm"
    >
      <form id="unit-form" class="grid gap-4 sm:grid-cols-2" @submit.prevent="save">
        <div>
          <label class="cc-label" for="u-eq">Tipo de equipo</label>
          <select id="u-eq" v-model="equipmentType" class="cc-field">
            <option v-for="e in EQUIPMENT_TYPES" :key="e" :value="e">{{ e }}</option>
          </select>
        </div>
        <div>
          <label class="cc-label" for="u-st">Estado</label>
          <select id="u-st" v-model="status" class="cc-field">
            <option v-for="s in UNIT_STATUSES" :key="s" :value="s">{{ s }}</option>
          </select>
        </div>
        <div>
          <label class="cc-label" for="u-pl">Placas</label>
          <input id="u-pl" v-model="plates" class="cc-field uppercase" placeholder="58-AK-3K" />
        </div>
        <div>
          <label class="cc-label" for="u-tr">Número de caja</label>
          <input id="u-tr" v-model="trailerNumber" class="cc-field" placeholder="Opcional" />
        </div>
        <div>
          <label class="cc-label" for="u-loc">Ubicación actual</label>
          <select id="u-loc" v-model="currentLocation" class="cc-field">
            <option v-for="s in MEXICAN_STATES" :key="s" :value="s">{{ s }}</option>
          </select>
        </div>
        <div>
          <label class="cc-label" for="u-op">Operador</label>
          <input id="u-op" v-model="operatorName" class="cc-field" placeholder="Nombre completo" />
        </div>
        <div>
          <label class="cc-label" for="u-scac">SCAC</label>
          <input id="u-scac" v-model="scac" class="cc-field uppercase" />
        </div>
        <div>
          <label class="cc-label" for="u-caat">CAAT</label>
          <input id="u-caat" v-model="caat" class="cc-field uppercase" />
        </div>
        <div class="sm:col-span-2">
          <label class="cc-label" for="u-notes">Notas</label>
          <textarea id="u-notes" v-model="notes" class="cc-field" placeholder="Opcional" />
        </div>
      </form>
      <template #footer>
        <button type="button" class="cc-btn-secondary flex-1" @click="closeForm">Cancelar</button>
        <button type="submit" form="unit-form" class="cc-btn flex-1" :disabled="busy">
          {{ busy ? 'Guardando…' : editingId ? 'Guardar cambios' : 'Agregar unidad' }}
        </button>
      </template>
    </SheetModal>

    <ConfirmModal
      :open="Boolean(deleting)"
      title="¿Eliminar unidad?"
      confirm-label="Eliminar"
      danger
      @close="deleting = null"
      @confirm="confirmRemove"
    >
      Se eliminará la unidad <strong class="text-navy">{{ deleting?.plates || 'sin placas' }}</strong>.
      Esta acción no se puede deshacer.
    </ConfirmModal>
  </div>
</template>
