<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import type { AppUser } from '@/lib/models';
import { Truck, TriangleAlert } from '@lucide/vue';
import { useDataStore, type TakeLoadResult } from '@/stores/data';
import { unitIsAvailableFor, type Load } from '@/lib/models';
import { formatMoney, parseTariff, toDatetimeLocalValue, fromDatetimeLocalValue } from '@/lib/format';
import { useMobileActionBar } from '@/lib/mobile-action-bar';
import ActionPanel from '@/components/ActionPanel.vue';
import ResultState from '@/components/ResultState.vue';

const props = defineProps<{ load: Load }>();
const emit = defineEmits<{ close: []; done: [] }>();

const store = useDataStore();
const { style: confirmBarStyle } = useMobileActionBar();
const selectedUnitId = ref<string>('');
const availableUnitCount = ref(1);
const proposedPriceText = ref('');
const operatorPhone = ref('');
const foundOperator = ref<AppUser | null>(null);
const operatorLookup = ref<'idle' | 'pending' | 'found' | 'missing'>('idle');
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

const proposedPricePerUnit = computed(() => parseTariff(proposedPriceText.value));

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

let lookupTimer: ReturnType<typeof setTimeout> | undefined;
watch(operatorPhone, (phone) => {
  clearTimeout(lookupTimer);
  foundOperator.value = null;
  if (!phone.replace(/\D/g, '')) {
    operatorLookup.value = 'idle';
    return;
  }
  operatorLookup.value = 'pending';
  lookupTimer = setTimeout(async () => {
    const found = await store.lookupOperator(phone);
    if (operatorPhone.value !== phone) return;
    foundOperator.value = found;
    operatorLookup.value = found ? 'found' : 'missing';
  }, 350);
});

async function confirm() {
  const proposed = proposedPricePerUnit.value;
  if (!canConfirm.value || proposed == null) return;
  const eta = fromDatetimeLocalValue(unitETA.value);
  if (Number.isNaN(eta.getTime())) {
    error.value = 'Revisa la fecha de llegada al origen.';
    return;
  }
  isConfirming.value = true;
  error.value = '';
  try {
    if (needsAdminApproval.value) {
      result.value = await store.submitCounterOffer({
        loadId: props.load.id,
        unitId: selectedUnitId.value || undefined,
        operatorId: foundOperator.value?.uuid,
        unitETA: eta,
        trackingUrl: trackingUrl.value.trim(),
        availableUnitCount: availableUnitCount.value,
        proposedPricePerUnit: proposed,
      });
    } else {
      result.value = await store.takeLoad({
        loadId: props.load.id,
        unitId: selectedUnitId.value || undefined,
        operatorId: foundOperator.value?.uuid,
        unitETA: eta,
        trackingUrl: trackingUrl.value.trim(),
        availableUnitCount: availableUnitCount.value,
        proposedPricePerUnit: proposed,
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
            type="text"
            inputmode="decimal"
            autocomplete="off"
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
        <p
          v-if="foundOperator"
          class="mt-2 rounded-xl bg-success-soft px-3 py-2 text-xs font-medium text-success"
        >
          {{ foundOperator.name }}
          · {{ foundOperator.role === 'independent_operator' ? 'Operador independiente' : 'Transportista' }}
        </p>
        <p v-else-if="operatorLookup === 'missing'" class="cc-hint">
          Número no encontrado. El viaje se registrará sin operador asignado.
        </p>
      </div>

      <p v-if="proposedPricePerUnit == null" class="text-xs text-danger">Escribe un precio mayor a cero.</p>
      <div class="h-24 md:hidden" aria-hidden="true" />
    </template>
  </ActionPanel>

  <Teleport to="body">
    <div
      v-if="!result"
      class="fixed z-40 border-t border-line bg-card/95 px-4 py-3 shadow-elevated backdrop-blur-md"
      :style="confirmBarStyle"
    >
      <p v-if="error" class="mb-2 text-sm text-danger">{{ error }}</p>
      <button
        type="button"
        class="cc-btn h-12 w-full"
        :disabled="!canConfirm || proposedPricePerUnit == null || isConfirming"
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
    </div>
  </Teleport>
</template>
