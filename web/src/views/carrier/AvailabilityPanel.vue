<script setup lang="ts">
import { computed, ref } from 'vue';
import { useDataStore } from '@/stores/data';
import { type Load, unitIsAvailableFor } from '@/lib/models';
import { formatMoney } from '@/lib/format';

const props = defineProps<{ load: Load }>();
const emit = defineEmits<{ close: []; done: [] }>();

const store = useDataStore();
const unitId = ref('');
const proposePrice = ref(false);
const priceText = ref(String(Math.round(props.load.offeredPrice)));
const done = ref(false);
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

async function submit() {
  busy.value = true;
  try {
    await store.indicateAvailability(
      props.load.id,
      unitId.value || undefined,
      proposePrice.value ? Number(priceText.value) || undefined : undefined,
    );
    done.value = true;
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <div class="mt-4 rounded-2xl border border-line bg-card p-4">
    <div class="mb-3 flex items-center justify-between">
      <h2 class="text-base font-semibold text-navy">Indicar disponibilidad</h2>
      <button type="button" class="text-sm text-muted" @click="emit('close')">Cancelar</button>
    </div>

    <template v-if="done">
      <p class="rounded-xl bg-success-soft px-4 py-4 text-center text-sm font-medium text-success">
        Disponibilidad registrada. Continente Cargo confirmará la asignación.
      </p>
      <button type="button" class="cc-btn mt-4 h-10 text-sm" @click="emit('done')">Listo</button>
    </template>

    <template v-else>
      <p class="mb-3 text-sm text-muted">
        Precio de referencia: {{ formatMoney(load.offeredPrice, load.currency) }}
      </p>
      <label class="cc-label">Unidad (opcional)</label>
      <select v-model="unitId" class="cc-field mb-3">
        <option value="">Sin unidad</option>
        <option v-for="u in units" :key="u.id" :value="u.id">
          {{ u.plates || u.trailerNumber || u.id.slice(0, 8) }}
        </option>
      </select>
      <label class="mb-3 flex items-center gap-2 text-sm">
        <input v-model="proposePrice" type="checkbox" class="size-4" />
        Proponer precio distinto
      </label>
      <input
        v-if="proposePrice"
        v-model="priceText"
        type="number"
        min="0"
        class="cc-field mb-3"
      />
      <button type="button" class="cc-btn" :disabled="busy" @click="submit">
        {{ busy ? 'Enviando…' : 'Enviar disponibilidad' }}
      </button>
    </template>
  </div>
</template>
