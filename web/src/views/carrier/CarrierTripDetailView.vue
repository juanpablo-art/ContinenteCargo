<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import InfoRow from '@/components/InfoRow.vue';
import StatusBadge from '@/components/StatusBadge.vue';
import { useDataStore } from '@/stores/data';
import {
  loadDestinationDisplay,
  loadOriginDisplay,
  type LoadStatus,
} from '@/lib/models';
import { formatDateTime, formatMoney } from '@/lib/format';

const TRIP_ADVANCE: LoadStatus[] = [
  'Asignado',
  'En camino a recolección',
  'En origen',
  'Cargado',
  'En tránsito',
  'Entregado',
];

const route = useRoute();
const router = useRouter();
const store = useDataStore();

const load = computed(() => store.loadById(String(route.params.id)));
const next = computed(() => {
  if (!load.value) return null;
  const i = TRIP_ADVANCE.indexOf(load.value.status);
  if (i < 0 || i >= TRIP_ADVANCE.length - 1) return null;
  return TRIP_ADVANCE[i + 1];
});
const tracking = ref('');
const msg = ref('');

const mapsUrl = computed(() => {
  if (!load.value) return '#';
  const q = encodeURIComponent(
    load.value.exactPickupAddress || loadOriginDisplay(load.value),
  );
  return `https://www.google.com/maps/search/?api=1&query=${q}`;
});

async function advance() {
  if (!load.value || !next.value) return;
  if (tracking.value) {
    await store.updateLoadStatus(load.value.id, next.value);
    const { updateLoadFields } = await import('@/lib/firestore-data');
    await updateLoadFields(load.value.id, {
      trackingUrl: tracking.value || load.value.trackingUrl,
    });
  } else {
    await store.updateLoadStatus(load.value.id, next.value);
  }
  msg.value = `Estado actualizado a ${next.value}`;
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
      <InfoRow
        label="Precio"
        :value="formatMoney(load.assignedPriceSinIVA ?? load.offeredPrice, load.currency)"
      />
      <InfoRow label="Equipo" :value="load.equipmentType" />
      <InfoRow label="Recolección" :value="formatDateTime(load.pickupDate)" />
      <template v-if="store.canSeePrivateFields(load)">
        <InfoRow label="Cliente" :value="load.clientContactName" />
        <InfoRow label="Tel." :value="load.clientContactPhone" />
        <InfoRow label="Dir. origen" :value="load.exactPickupAddress" />
        <InfoRow label="Dir. destino" :value="load.exactDeliveryAddress" />
      </template>
    </dl>

    <a :href="mapsUrl" target="_blank" rel="noopener" class="mt-3 inline-block text-sm font-semibold text-blue">
      Abrir en Google Maps
    </a>

    <section v-if="load.cartaInstruccion" class="mt-5 rounded-2xl border border-line bg-card p-4">
      <h2 class="text-sm font-semibold text-navy">Carta de instrucción</h2>
      <InfoRow label="Folio" :value="load.cartaInstruccion.folio" />
      <InfoRow label="Obs." :value="load.cartaInstruccion.observaciones" />
    </section>

    <section class="mt-5">
      <h2 class="mb-2 text-sm font-semibold uppercase text-muted">Historial</h2>
      <ul class="space-y-2">
        <li
          v-for="h in [...load.statusHistory].reverse()"
          :key="h.id"
          class="rounded-xl border border-line px-3 py-2 text-sm"
        >
          <p class="font-medium">{{ h.status }}</p>
          <p class="text-xs text-muted">{{ formatDateTime(h.changedAt) }} · {{ h.changedByName }}</p>
        </li>
      </ul>
    </section>

    <section v-if="next" class="mt-6 space-y-3 rounded-2xl border border-line bg-card p-4">
      <h2 class="text-sm font-semibold text-navy">Actualizar viaje</h2>
      <input v-model="tracking" class="cc-field" :placeholder="load.trackingUrl || 'URL de rastreo'" />
      <p v-if="msg" class="text-sm text-success">{{ msg }}</p>
      <button type="button" class="cc-btn" @click="advance">Avanzar a: {{ next }}</button>
    </section>
  </div>
  <div v-else class="p-8 text-center text-muted">Viaje no encontrado</div>
</template>
