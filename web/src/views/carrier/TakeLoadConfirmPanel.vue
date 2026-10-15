<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useDataStore, type TakeLoadResult } from '@/stores/data';
import {
  loadDestinationDisplay,
  loadOriginDisplay,
  unitIsAvailableFor,
  type Load,
} from '@/lib/models';
import { formatDate, formatMoney, toDatetimeLocalValue, fromDatetimeLocalValue } from '@/lib/format';

const props = defineProps<{ load: Load }>();
const emit = defineEmits<{ close: []; done: [] }>();

const store = useDataStore();
const selectedUnitId = ref<string>('');
const availableUnitCount = ref(1);
const proposedPriceText = ref('');
const operatorPhone = ref('');
const unitETA = ref(toDatetimeLocalValue(props.load.pickupDate));
const trackingUrl = ref('');
const result = ref<TakeLoadResult | null>(null);
const isConfirming = ref(false);
const error = ref('');

const maxPositionable = computed(() =>
  Math.max(1, props.load.unitCount - props.load.confirmedUnitCount),
);

const availableUnits = computed(() =>
  store
    .myUnits()
    .filter(
      (u) =>
        u.notes !== 'availability_post' &&
        unitIsAvailableFor(u, props.load.pickupDate) &&
        u.equipmentType === props.load.equipmentType,
    ),
);

const proposedPricePerUnit = computed(() => {
  const digits = proposedPriceText.value.replace(/[^\d.]/g, '');
  return digits ? Number(digits) : null;
});

/** Uses maxAuthorizedPriceSinIVA for logic only — never displayed to carrier. */
const needsAdminApproval = computed(() => {
  const proposed = proposedPricePerUnit.value;
  if (proposed == null) return false;
  if (proposed <= props.load.offeredPrice) return false;
  if (props.load.maxAuthorizedPriceSinIVA != null) {
    return proposed > props.load.maxAuthorizedPriceSinIVA;
  }
  return true;
});

const canConfirm = computed(() => {
  if (props.load.unitCount > 1) return true;
  return Boolean(selectedUnitId.value);
});

watch(
  () => props.load.id,
  () => {
    proposedPriceText.value = String(Math.round(props.load.offeredPrice));
    availableUnitCount.value = maxPositionable.value;
    unitETA.value = toDatetimeLocalValue(props.load.pickupDate);
    if (availableUnits.value.length === 1) {
      selectedUnitId.value = availableUnits.value[0].id;
    }
  },
  { immediate: true },
);

async function confirm() {
  if (!canConfirm.value) return;
  isConfirming.value = true;
  error.value = '';
  try {
    const proposed = proposedPricePerUnit.value ?? props.load.offeredPrice;
    if (needsAdminApproval.value) {
      result.value = await store.submitCounterOffer({
        loadId: props.load.id,
        unitId: selectedUnitId.value || undefined,
        unitETA: fromDatetimeLocalValue(unitETA.value),
        trackingUrl: trackingUrl.value.trim(),
        availableUnitCount: availableUnitCount.value,
        proposedPricePerUnit: proposed,
      });
    } else {
      result.value = await store.takeLoad({
        loadId: props.load.id,
        unitId: selectedUnitId.value || undefined,
        unitETA: fromDatetimeLocalValue(unitETA.value),
        trackingUrl: trackingUrl.value.trim(),
        availableUnitCount: availableUnitCount.value,
      });
    }
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Error al confirmar';
  } finally {
    isConfirming.value = false;
  }
}

function resultTitle(r: TakeLoadResult) {
  switch (r) {
    case 'success':
      return '¡Participación confirmada!';
    case 'pendingApproval':
      return 'Propuesta enviada';
    case 'alreadyAssigned':
      return 'Ya no disponible';
    case 'deadlinePassed':
      return 'Plazo vencido';
    case 'notApproved':
      return 'Cuenta no aprobada';
    case 'noUnit':
      return 'Unidad no válida';
    default:
      return 'Resultado';
  }
}

function resultBody(r: TakeLoadResult) {
  switch (r) {
    case 'success':
      return 'Confirmaste tu unidad para este viaje.';
    case 'pendingApproval':
      return 'Tu contra-oferta requiere aprobación del administrador.';
    case 'alreadyAssigned':
      return 'Esta carga ya fue tomada o está completa.';
    case 'deadlinePassed':
      return 'El plazo para participar ya cerró.';
    case 'notApproved':
      return 'Tu cuenta aún no está aprobada.';
    case 'noUnit':
      return 'Selecciona una unidad disponible válida.';
    default:
      return '';
  }
}
</script>

<template>
  <div class="mt-4 rounded-2xl border border-line bg-card p-4">
    <div class="mb-3 flex items-center justify-between">
      <h2 class="text-base font-semibold text-navy">Confirmar toma de carga</h2>
      <button type="button" class="text-sm text-muted" @click="emit('close')">Cancelar</button>
    </div>

    <template v-if="result">
      <div
        class="rounded-xl px-4 py-5 text-center"
        :class="
          result === 'success' || result === 'pendingApproval'
            ? 'bg-success-soft text-success'
            : 'bg-danger-soft text-danger'
        "
      >
        <p class="font-semibold">{{ resultTitle(result) }}</p>
        <p class="mt-1 text-sm opacity-90">{{ resultBody(result) }}</p>
        <button type="button" class="cc-btn mt-4 h-10 text-sm" @click="emit('done')">
          Listo
        </button>
      </div>
    </template>

    <template v-else>
      <p v-if="error" class="mb-3 rounded-lg bg-danger-soft px-3 py-2 text-sm text-danger">
        {{ error }}
      </p>

      <div class="mb-4 space-y-1 rounded-xl bg-background p-3 text-sm">
        <p class="font-medium text-navy">{{ load.reference }}</p>
        <p class="text-muted">
          {{ loadOriginDisplay(load) }} → {{ loadDestinationDisplay(load) }}
        </p>
        <p class="text-muted">Recolección: {{ formatDate(load.pickupDate) }}</p>
      </div>

      <div class="mb-4 space-y-2">
        <p class="text-sm font-semibold text-navy">Precio</p>
        <div class="flex justify-between text-sm">
          <span class="text-muted">Precio publicado</span>
          <span class="font-semibold">{{ formatMoney(load.offeredPrice, load.currency) }}</span>
        </div>
        <label class="cc-label">Tu propuesta (sin IVA, por unidad)</label>
        <div class="flex items-center gap-2">
          <span class="text-sm text-muted">{{ load.currency }}</span>
          <input v-model="proposedPriceText" type="number" min="0" class="cc-field" />
        </div>
        <p
          v-if="needsAdminApproval"
          class="rounded-lg bg-orange-soft px-3 py-2 text-xs text-orange"
        >
          Tu precio supera el máximo autorizado. Se enviará al administrador para aprobación.
        </p>
      </div>

      <div v-if="load.unitCount > 1" class="mb-4">
        <label class="cc-label">Unidades que aportas (máx. {{ maxPositionable }})</label>
        <input
          v-model.number="availableUnitCount"
          type="number"
          :min="1"
          :max="maxPositionable"
          class="cc-field"
        />
      </div>

      <div class="mb-4">
        <label class="cc-label">
          Unidad {{ load.unitCount > 1 ? '(opcional)' : '*' }}
        </label>
        <select v-model="selectedUnitId" class="cc-field">
          <option value="">Seleccionar…</option>
          <option v-for="u in availableUnits" :key="u.id" :value="u.id">
            {{ u.plates || u.trailerNumber || u.id.slice(0, 8) }} · {{ u.equipmentType }}
          </option>
        </select>
        <p v-if="!availableUnits.length" class="mt-1 text-xs text-orange">
          No tienes unidades disponibles de este tipo.
          <RouterLink :to="{ name: 'carrier-units' }" class="font-medium text-brand underline">
            Agregar unidad
          </RouterLink>
        </p>
      </div>

      <div class="mb-4 grid gap-3 sm:grid-cols-2">
        <div>
          <label class="cc-label">ETA en origen</label>
          <input v-model="unitETA" type="datetime-local" class="cc-field" />
        </div>
        <div>
          <label class="cc-label">URL de rastreo (opcional)</label>
          <input v-model="trackingUrl" class="cc-field" placeholder="https://…" />
        </div>
      </div>

      <div class="mb-4">
        <label class="cc-label">Teléfono operador (opcional)</label>
        <input v-model="operatorPhone" class="cc-field" placeholder="10 dígitos" />
      </div>

      <button
        type="button"
        class="cc-btn"
        :disabled="!canConfirm || isConfirming"
        @click="confirm"
      >
        {{
          isConfirming
            ? 'Confirmando…'
            : needsAdminApproval
              ? 'Enviar propuesta al administrador'
              : 'Confirmar – Tomar carga'
        }}
      </button>
    </template>
  </div>
</template>
