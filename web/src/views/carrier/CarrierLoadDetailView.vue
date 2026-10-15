<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import InfoRow from '@/components/InfoRow.vue';
import StatusBadge from '@/components/StatusBadge.vue';
import { useDataStore } from '@/stores/data';
import {
  loadDestinationDisplay,
  loadOriginDisplay,
} from '@/lib/models';
import { formatDateTime, formatMoney } from '@/lib/format';

const route = useRoute();
const router = useRouter();
const store = useDataStore();

const load = computed(() => store.loadById(String(route.params.id)));
const showSensitive = computed(() =>
  load.value ? store.canSeePrivateFields(load.value) : false,
);

const unitsCount = ref(1);
const price = ref(0);
const trackingUrl = ref('');
const eta = ref('');
const busy = ref(false);
const resultMsg = ref('');

watch(
  load,
  (l) => {
    if (l) price.value = l.offeredPrice;
  },
  { immediate: true },
);

const ctaLabel = computed(() => {
  if (!load.value) return 'Confirmar';
  if (
    price.value > load.value.offeredPrice &&
    load.value.maxAuthorizedPriceSinIVA == null
  ) {
    return 'Enviar propuesta al administrador';
  }
  if (load.value.assignmentMode === 'Subasta Inversa') return 'Enviar oferta';
  if (load.value.assignmentMode === 'Confirmación Manual') return 'Indicar disponibilidad';
  if (load.value.assignmentMode === 'Consolidada LTL') return 'Enviar cotización LTL';
  return 'Confirmar – Tomar carga';
});

async function confirm() {
  if (!load.value) return;
  busy.value = true;
  resultMsg.value = '';
  try {
    const l = load.value;
    if (
      price.value > l.offeredPrice &&
      l.maxAuthorizedPriceSinIVA == null
    ) {
      const res = await store.submitCounterOffer({
        loadId: l.id,
        availableUnitCount: unitsCount.value,
        proposedPricePerUnit: price.value,
        trackingUrl: trackingUrl.value,
        unitETA: eta.value ? new Date(eta.value) : undefined,
      });
      resultMsg.value =
        res === 'pendingApproval'
          ? 'Propuesta enviada al administrador'
          : String(res);
      return;
    }

    if (l.assignmentMode === 'Subasta Inversa') {
      const res = await store.placeBid({
        loadId: l.id,
        amount: price.value,
        availableUnitCount: unitsCount.value,
      });
      resultMsg.value = res === 'success' ? 'Oferta enviada' : String(res);
      return;
    }

    if (l.assignmentMode === 'Confirmación Manual') {
      await store.indicateAvailability(l.id, undefined, price.value);
      resultMsg.value = 'Disponibilidad indicada';
      return;
    }

    if (l.assignmentMode === 'Consolidada LTL') {
      const ok = await store.submitLTLQuote(l.id, price.value);
      resultMsg.value = ok ? 'Cotización enviada' : 'No se pudo enviar';
      return;
    }

    const res = await store.takeLoad({
      loadId: l.id,
      availableUnitCount: unitsCount.value,
      trackingUrl: trackingUrl.value,
      unitETA: eta.value ? new Date(eta.value) : undefined,
    });
    if (res === 'success') {
      resultMsg.value = 'Participación confirmada';
      await router.push({ name: 'carrier-trips' });
    } else {
      resultMsg.value = String(res);
    }
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <div v-if="load" class="mx-auto w-full max-w-2xl px-4 py-6 sm:px-6">
    <button type="button" class="mb-3 text-sm text-blue" @click="router.back()">← Volver</button>
    <div class="flex items-start justify-between gap-3">
      <div>
        <p class="text-xs text-muted">{{ load.reference }}</p>
        <h1 class="text-2xl font-bold text-navy">
          {{ loadOriginDisplay(load) }} → {{ loadDestinationDisplay(load) }}
        </h1>
      </div>
      <StatusBadge :status="load.status" />
    </div>

    <dl class="mt-5 rounded-2xl border border-line bg-card p-4">
      <InfoRow label="Modalidad" :value="load.assignmentMode" />
      <InfoRow label="Equipo" :value="load.equipmentType" />
      <InfoRow label="Unidades" :value="String(load.unitCount)" />
      <InfoRow label="Precio / u" :value="formatMoney(load.offeredPrice, load.currency)" />
      <InfoRow
        label="Total"
        :value="formatMoney(load.offeredPrice * Math.max(1, load.unitCount), load.currency)"
      />
      <InfoRow label="Recolección" :value="formatDateTime(load.pickupDate)" />
      <InfoRow label="Deadline" :value="formatDateTime(load.deadline)" />
      <InfoRow label="Mercancía" :value="load.merchandiseDescription || '—'" />
      <template v-if="showSensitive">
        <InfoRow label="Cliente" :value="load.clientContactName" />
        <InfoRow label="Tel." :value="load.clientContactPhone" />
        <InfoRow label="Dir. origen" :value="load.exactPickupAddress" />
        <InfoRow label="Dir. destino" :value="load.exactDeliveryAddress" />
      </template>
    </dl>

    <section
      v-if="load.status === 'Publicado'"
      class="mt-6 space-y-3 rounded-2xl border border-line bg-card p-4"
    >
      <h2 class="text-sm font-semibold text-navy">Participar</h2>
      <div v-if="load.unitCount > 1">
        <label class="cc-label">Unidades a posicionar</label>
        <input
          v-model.number="unitsCount"
          type="number"
          min="1"
          :max="load.unitCount - load.confirmedUnitCount"
          class="cc-field"
        />
      </div>
      <div>
        <label class="cc-label">Precio propuesto / unidad</label>
        <input v-model.number="price" type="number" class="cc-field" />
      </div>
      <div>
        <label class="cc-label">ETA unidad (opcional)</label>
        <input v-model="eta" type="datetime-local" class="cc-field" />
      </div>
      <div>
        <label class="cc-label">URL de rastreo (opcional)</label>
        <input v-model="trackingUrl" class="cc-field" />
      </div>
      <p v-if="resultMsg" class="text-sm text-muted">{{ resultMsg }}</p>
      <button type="button" class="cc-btn" :disabled="busy" @click="confirm">
        {{ busy ? 'Enviando…' : ctaLabel }}
      </button>
    </section>
  </div>
  <div v-else class="p-8 text-center text-muted">Carga no encontrada</div>
</template>
