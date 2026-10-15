<script setup lang="ts">
import { ref } from 'vue';
import { useDataStore } from '@/stores/data';
import type { Load } from '@/lib/models';

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
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <div class="mt-4 rounded-2xl border border-line bg-card p-4">
    <div class="mb-3 flex items-center justify-between">
      <h2 class="text-base font-semibold text-navy">Cotización LTL</h2>
      <button type="button" class="text-sm text-muted" @click="emit('close')">Cancelar</button>
    </div>

    <template v-if="ok">
      <p class="rounded-xl bg-success-soft px-4 py-4 text-center text-sm font-medium text-success">
        Cotización enviada. El administrador confirmará al ganador.
      </p>
      <button type="button" class="cc-btn mt-4 h-10 text-sm" @click="emit('done')">Listo</button>
    </template>

    <template v-else>
      <p v-if="failed" class="mb-3 rounded-lg bg-danger-soft px-3 py-2 text-sm text-danger">
        No se pudo enviar. ¿Ya cotizaste esta carga o el plazo cerró?
      </p>
      <p v-if="load.measurementsDescription" class="mb-2 text-sm text-muted">
        Medidas: {{ load.measurementsDescription }}
      </p>
      <p class="mb-3 text-sm text-muted">
        Peso: {{ Math.round(load.weightKg).toLocaleString('es-MX') }} kg
      </p>
      <label class="cc-label">Tu cotización ({{ load.currency }})</label>
      <input v-model="amountText" type="number" min="0" class="cc-field mb-3" />
      <label class="cc-label">Notas</label>
      <textarea v-model="notes" class="cc-field mb-3 min-h-[72px]" />
      <button
        type="button"
        class="cc-btn"
        :disabled="busy || !amountText"
        @click="submit"
      >
        {{ busy ? 'Enviando…' : 'Enviar cotización' }}
      </button>
    </template>
  </div>
</template>
