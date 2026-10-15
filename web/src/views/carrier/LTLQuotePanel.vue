<script setup lang="ts">
import { ref } from 'vue';
import { Boxes } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import type { Load } from '@/lib/models';
import ActionPanel from '@/components/ActionPanel.vue';
import ResultState from '@/components/ResultState.vue';

const props = defineProps<{ load: Load }>();
const emit = defineEmits<{ close: []; done: [] }>();

const store = useDataStore();
const amountText = ref('');
const notes = ref('');
const ok = ref(false);
const failed = ref(false);
const busy = ref(false);

async function submit() {
  busy.value = true;
  failed.value = false;
  try {
    ok.value = await store.submitLTLQuote(
      props.load.id,
      Number(amountText.value) || 0,
      notes.value.trim(),
    );
    if (!ok.value) failed.value = true;
  } catch {
    failed.value = true;
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <ActionPanel
    title="Cotización LTL"
    subtitle="Cada consolidadora cotiza su propio precio"
    :icon="Boxes"
    @close="emit('close')"
  >
    <ResultState
      v-if="ok"
      ok
      title="Cotización enviada"
      body="El administrador revisará las cotizaciones y confirmará al ganador."
      @action="emit('done')"
    />

    <template v-else>
      <p v-if="failed" class="rounded-xl bg-danger-soft px-3.5 py-2.5 text-sm text-danger">
        No se pudo enviar. ¿Ya cotizaste esta carga o el plazo cerró?
      </p>
      <div class="grid grid-cols-2 gap-2 text-sm">
        <div class="rounded-xl bg-background px-3 py-2.5">
          <p class="text-[11px] font-medium text-muted">Peso</p>
          <p class="font-semibold text-navy">
            {{ Math.round(load.weightKg).toLocaleString('es-MX') }} kg
          </p>
        </div>
        <div class="rounded-xl bg-background px-3 py-2.5">
          <p class="text-[11px] font-medium text-muted">Medidas</p>
          <p class="truncate font-semibold text-navy">{{ load.measurementsDescription || '—' }}</p>
        </div>
      </div>
      <div>
        <label class="cc-label" for="ltl-amount">Tu cotización</label>
        <div class="relative">
          <span class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm font-medium text-muted">
            {{ load.currency }} $
          </span>
          <input
            id="ltl-amount"
            v-model="amountText"
            type="number"
            min="0"
            inputmode="numeric"
            class="cc-field pl-16 font-semibold tabular-nums"
            placeholder="0"
          />
        </div>
      </div>
      <div>
        <label class="cc-label" for="ltl-notes">Notas</label>
        <textarea
          id="ltl-notes"
          v-model="notes"
          class="cc-field"
          placeholder="Tiempo de tránsito, condiciones, etc."
        />
      </div>
      <button type="button" class="cc-btn" :disabled="busy || !amountText" @click="submit">
        {{ busy ? 'Enviando…' : 'Enviar cotización' }}
      </button>
    </template>
  </ActionPanel>
</template>
