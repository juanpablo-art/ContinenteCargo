<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { Truck, TriangleAlert } from '@lucide/vue';
import { useDataStore, type TakeLoadResult } from '@/stores/data';
import { unitIsAvailableFor, type Load } from '@/lib/models';
import { formatMoney, toDatetimeLocalValue, fromDatetimeLocalValue } from '@/lib/format';
import ActionPanel from '@/components/ActionPanel.vue';
import ResultState from '@/components/ResultState.vue';

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
  <ActionPanel
    title="Confirmar toma de carga"
    :subtitle="`${load.reference} · ${load.originCity} → ${load.destinationCity}`"
    :icon="Truck"
    @close="emit('close')"
  >
    <ResultState
      v-if="result"
      :ok="result === 'success' || result === 'pendingApproval'"
      :title="resultTitle(result)"
      :body="resultBody(result)"
      @action="emit('done')"
    />

    <template v-else>
      <p v-if="error" class="rounded-xl bg-danger-soft px-3.5 py-2.5 text-sm text-danger">
        {{ error }}
      </p>

      <div>
        <div class="mb-1.5 flex items-baseline justify-between">
          <label class="cc-label mb-0" for="take-price">Tu precio por unidad (sin IVA)</label>
          <span class="text-xs text-muted">
            Publicado {{ formatMoney(load.offeredPrice, load.currency) }}
          </span>
        </div>
        <div class="relative">
          <span class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm font-medium text-muted">
            {{ load.currency }} $
          </span>
          <input
            id="take-price"
            v-model="proposedPriceText"
            type="number"
            min="0"
            inputmode="numeric"
            class="cc-field pl-16 text-lg font-semibold tabular-nums"
          />
        </div>
        <p
          v-if="needsAdminApproval"
          class="mt-2 flex items-start gap-2 rounded-xl bg-orange-soft px-3 py-2.5 text-xs leading-relaxed text-orange"
        >
          <TriangleAlert class="mt-px size-4 shrink-0" aria-hidden="true" />
          Tu precio supera el máximo autorizado. Se enviará al administrador para aprobación.
        </p>
      </div>

      <div v-if="load.unitCount > 1">
        <label class="cc-label" for="take-count">Unidades que aportas (máx. {{ maxPositionable }})</label>
        <input
          id="take-count"
          v-model.number="availableUnitCount"
          type="number"
          :min="1"
          :max="maxPositionable"
          class="cc-field"
        />
      </div>

      <div>
        <label class="cc-label" for="take-unit">
          Unidad {{ load.unitCount > 1 ? '(opcional)' : '' }}
        </label>
        <select id="take-unit" v-model="selectedUnitId" class="cc-field">
          <option value="">Seleccionar…</option>
          <option v-for="u in availableUnits" :key="u.id" :value="u.id">
            {{ u.plates || u.trailerNumber || u.id.slice(0, 8) }} · {{ u.equipmentType }}
          </option>
        </select>
        <p v-if="!availableUnits.length" class="cc-hint text-orange">
          No tienes unidades {{ load.equipmentType }} disponibles.
          <RouterLink :to="{ name: 'carrier-units' }" class="font-semibold text-brand hover:underline">
            Agregar unidad
          </RouterLink>
        </p>
      </div>

      <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-1">
        <div>
          <label class="cc-label" for="take-eta">ETA en origen</label>
          <input id="take-eta" v-model="unitETA" type="datetime-local" class="cc-field" />
        </div>
        <div>
          <label class="cc-label" for="take-track">URL de rastreo (opcional)</label>
          <input id="take-track" v-model="trackingUrl" type="url" class="cc-field" placeholder="https://…" />
        </div>
      </div>

      <div>
        <label class="cc-label" for="take-phone">Teléfono del operador (opcional)</label>
        <input
          id="take-phone"
          v-model="operatorPhone"
          type="tel"
          inputmode="tel"
          class="cc-field"
          placeholder="10 dígitos"
        />
      </div>

      <button
        type="button"
        class="cc-btn h-12"
        :disabled="!canConfirm || isConfirming"
        @click="confirm"
      >
        {{
          isConfirming
            ? 'Confirmando…'
            : needsAdminApproval
              ? 'Enviar propuesta al administrador'
              : 'Confirmar y tomar carga'
        }}
      </button>
    </template>
  </ActionPanel>
</template>
