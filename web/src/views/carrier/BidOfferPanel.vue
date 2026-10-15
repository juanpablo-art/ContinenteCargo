<script setup lang="ts">
import { computed, ref } from 'vue';
import { useDataStore, type BidResult } from '@/stores/data';
import { type Load, unitIsAvailableFor } from '@/lib/models';
import { formatMoney } from '@/lib/format';

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

async function submit() {
  busy.value = true;
  try {
    result.value = await store.placeBid({
      loadId: props.load.id,
      amount: Number(amountText.value) || 0,
      unitId: unitId.value || undefined,
      availableUnitCount: unitCount.value,
    });
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
  <div class="mt-4 rounded-2xl border border-line bg-card p-4">
    <div class="mb-3 flex items-center justify-between">
      <h2 class="text-base font-semibold text-navy">Subasta inversa</h2>
      <button type="button" class="text-sm text-muted" @click="emit('close')">Cancelar</button>
    </div>

    <template v-if="result">
      <p
        class="rounded-xl px-4 py-4 text-center text-sm font-medium"
        :class="result === 'success' ? 'bg-success-soft text-success' : 'bg-danger-soft text-danger'"
      >
        {{ label(result) }}
      </p>
      <button type="button" class="cc-btn mt-4 h-10 text-sm" @click="emit('done')">Listo</button>
    </template>

    <template v-else>
      <p class="mb-3 text-sm text-muted">
        Precio de referencia:
        <strong class="text-navy">{{ formatMoney(load.offeredPrice, load.currency) }}</strong>
        <span v-if="lowestBid != null">
          · Mejor oferta:
          <strong>{{ formatMoney(lowestBid, load.currency) }}</strong>
        </span>
      </p>
      <p class="mb-3 text-xs text-muted">
        Decremento mínimo: {{ formatMoney(load.minBidDecrement, load.currency) }}
      </p>
      <label class="cc-label">Tu oferta (total)</label>
      <input v-model="amountText" type="number" min="0" class="cc-field mb-3" />
      <label class="cc-label">Unidad (opcional)</label>
      <select v-model="unitId" class="cc-field mb-3">
        <option value="">Sin unidad</option>
        <option v-for="u in units" :key="u.id" :value="u.id">
          {{ u.plates || u.trailerNumber || u.id.slice(0, 8) }}
        </option>
      </select>
      <label v-if="load.unitCount > 1" class="cc-label">Unidades disponibles</label>
      <input
        v-if="load.unitCount > 1"
        v-model.number="unitCount"
        type="number"
        min="1"
        :max="load.unitCount"
        class="cc-field mb-3"
      />
      <button type="button" class="cc-btn" :disabled="busy" @click="submit">
        {{ busy ? 'Enviando…' : 'Enviar oferta' }}
      </button>
    </template>
  </div>
</template>
