<script setup lang="ts">
import { computed, ref } from 'vue';
import { Gavel } from '@lucide/vue';
import { useDataStore, type BidResult } from '@/stores/data';
import { type Load, unitIsAvailableFor } from '@/lib/models';
import { formatMoney } from '@/lib/format';
import ActionPanel from '@/components/ActionPanel.vue';
import ResultState from '@/components/ResultState.vue';
import { toast } from '@/lib/toast';

const props = defineProps<{ load: Load }>();
const emit = defineEmits<{ close: []; done: [] }>();

const store = useDataStore();
const amountText = ref(String(Math.round(props.load.offeredPrice)));
const unitId = ref('');
const unitCount = ref(1);
const result = ref<BidResult | null>(null);
const busy = ref(false);

const units = computed(() =>
  store
    .myUnits()
    .filter(
      (u) =>
        u.notes !== 'availability_post' &&
        unitIsAvailableFor(u, props.load.pickupDate) &&
        u.equipmentType === props.load.equipmentType,
    ),
);

const lowestBid = computed(() => {
  const offers = store
    .offersForLoad(props.load.id)
    .filter((o) => o.status === 'Activa' || o.status === 'Ganando');
  if (!offers.length) return null;
  return Math.min(...offers.map((o) => o.amount));
});

const suggested = computed(() =>
  lowestBid.value != null ? lowestBid.value - props.load.minBidDecrement : null,
);

async function submit() {
  busy.value = true;
  try {
    result.value = await store.placeBid({
      loadId: props.load.id,
      amount: Number(amountText.value) || 0,
      unitId: unitId.value || undefined,
      availableUnitCount: unitCount.value,
    });
  } catch (e) {
    toast.error('No se pudo enviar la oferta', e instanceof Error ? e.message : undefined);
  } finally {
    busy.value = false;
  }
}

function label(r: BidResult) {
  switch (r) {
    case 'success':
      return 'Oferta enviada';
    case 'decrementTooSmall':
      return `El decremento mínimo es ${formatMoney(props.load.minBidDecrement, props.load.currency)}`;
    case 'deadlinePassed':
      return 'El plazo ya cerró';
    case 'alreadyAssigned':
      return 'La carga ya no acepta ofertas';
    case 'notApproved':
      return 'Cuenta no aprobada';
    default:
      return r;
  }
}
</script>

<template>
  <ActionPanel
    title="Subasta inversa"
    subtitle="Gana la oferta más baja al cierre"
    :icon="Gavel"
    @close="emit('close')"
  >
    <ResultState
      v-if="result"
      :ok="result === 'success'"
      :title="label(result)"
      :body="result === 'success' ? 'Te avisaremos si alguien mejora tu oferta.' : undefined"
      :action-label="result === 'success' ? 'Listo' : 'Intentar de nuevo'"
      @action="result === 'success' ? emit('done') : (result = null)"
    />

    <template v-else>
      <div class="grid grid-cols-2 gap-2">
        <div class="rounded-xl bg-background px-3 py-2.5">
          <p class="text-[11px] font-medium text-muted">Referencia</p>
          <p class="cc-money text-sm">{{ formatMoney(load.offeredPrice, load.currency) }}</p>
        </div>
        <div class="rounded-xl bg-success-soft/70 px-3 py-2.5">
          <p class="text-[11px] font-medium text-success">Mejor oferta</p>
          <p class="cc-money text-sm">
            {{ lowestBid != null ? formatMoney(lowestBid, load.currency) : 'Sin ofertas' }}
          </p>
        </div>
      </div>
      <div>
        <label class="cc-label" for="bid-amount">Tu oferta (total)</label>
        <div class="relative">
          <span class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm font-medium text-muted">
            {{ load.currency }} $
          </span>
          <input
            id="bid-amount"
            v-model="amountText"
            type="number"
            min="0"
            inputmode="numeric"
            class="cc-field pl-16 text-lg font-semibold tabular-nums"
          />
        </div>
        <p class="cc-hint">
          Decremento mínimo {{ formatMoney(load.minBidDecrement, load.currency) }}
          <button
            v-if="suggested != null && suggested > 0"
            type="button"
            class="ml-1 font-semibold text-brand hover:underline"
            @click="amountText = String(suggested)"
          >
            Usar {{ formatMoney(suggested, load.currency) }}
          </button>
        </p>
      </div>
      <div>
        <label class="cc-label" for="bid-unit">Unidad (opcional)</label>
        <select id="bid-unit" v-model="unitId" class="cc-field">
          <option value="">Sin unidad específica</option>
          <option v-for="u in units" :key="u.id" :value="u.id">
            {{ u.plates || u.trailerNumber || u.id.slice(0, 8) }} · {{ u.equipmentType }}
          </option>
        </select>
      </div>
      <div v-if="load.unitCount > 1">
        <label class="cc-label" for="bid-count">Unidades disponibles</label>
        <input
          id="bid-count"
          v-model.number="unitCount"
          type="number"
          min="1"
          :max="load.unitCount"
          class="cc-field"
        />
      </div>
      <button type="button" class="cc-btn" :disabled="busy" @click="submit">
        {{ busy ? 'Enviando…' : 'Enviar oferta' }}
      </button>
    </template>
  </ActionPanel>
</template>
