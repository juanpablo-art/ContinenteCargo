<script setup lang="ts">
import { computed, ref } from 'vue';
import { CalendarCheck } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import { type Load, unitIsAvailableFor } from '@/lib/models';
import { formatMoney } from '@/lib/format';
import ActionPanel from '@/components/ActionPanel.vue';
import ResultState from '@/components/ResultState.vue';
import { toast } from '@/lib/toast';

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
  } catch (e) {
    toast.error('No se pudo registrar', e instanceof Error ? e.message : undefined);
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <ActionPanel
    title="Indicar disponibilidad"
    :subtitle="`Referencia ${formatMoney(load.offeredPrice, load.currency)}`"
    :icon="CalendarCheck"
    @close="emit('close')"
  >
    <ResultState
      v-if="done"
      ok
      title="Disponibilidad registrada"
      body="Continente Cargo revisará tu propuesta y confirmará la asignación."
      @action="emit('done')"
    />

    <template v-else>
      <div>
        <label class="cc-label" for="av-unit">Unidad (opcional)</label>
        <select id="av-unit" v-model="unitId" class="cc-field">
          <option value="">Sin unidad específica</option>
          <option v-for="u in units" :key="u.id" :value="u.id">
            {{ u.plates || u.trailerNumber || u.id.slice(0, 8) }} · {{ u.equipmentType }}
          </option>
        </select>
      </div>
      <label class="cc-check">
        <input v-model="proposePrice" type="checkbox" />
        Proponer un precio distinto
      </label>
      <div v-if="proposePrice" class="relative">
        <span class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm font-medium text-muted">
          {{ load.currency }} $
        </span>
        <input
          v-model="priceText"
          type="number"
          min="0"
          inputmode="numeric"
          class="cc-field pl-16 font-semibold tabular-nums"
          aria-label="Precio propuesto"
        />
      </div>
      <button type="button" class="cc-btn" :disabled="busy" @click="submit">
        {{ busy ? 'Enviando…' : 'Enviar disponibilidad' }}
      </button>
    </template>
  </ActionPanel>
</template>
