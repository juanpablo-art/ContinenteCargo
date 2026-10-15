<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { ArrowLeft } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import {
  LOAD_STATUSES,
  loadDestinationDisplay,
  loadOriginDisplay,
  type LoadStatus,
} from '@/lib/models';
import { formatDate, formatMoney, statusBadgeClass } from '@/lib/format';

const route = useRoute();
const router = useRouter();
const store = useDataStore();

const loadId = computed(() => String(route.params.id));
const load = computed(() => {
  const found = store.loadById(loadId.value);
  if (!found) return undefined;
  const trips = store.myTrips();
  return trips.some((t) => t.id === found.id) ? found : undefined;
});

const busy = ref(false);
const message = ref('');

const carrierProgressStatuses: LoadStatus[] = [
  'Asignado',
  'En camino a recolección',
  'En origen',
  'Cargado',
  'En tránsito',
  'Entregado',
];

const nextStatus = computed(() => {
  if (!load.value) return null;
  const idx = carrierProgressStatuses.indexOf(load.value.status);
  if (idx < 0 || idx >= carrierProgressStatuses.length - 1) return null;
  return carrierProgressStatuses[idx + 1];
});

const showPrivate = computed(() =>
  load.value ? store.canSeePrivateFields(load.value) : false,
);

async function advance() {
  if (!load.value || !nextStatus.value) return;
  busy.value = true;
  try {
    await store.updateLoadStatus(load.value.id, nextStatus.value);
    message.value = `Estado actualizado a ${nextStatus.value}`;
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <div class="mx-auto max-w-3xl px-4 py-5 md:px-6">
    <button
      type="button"
      class="mb-4 inline-flex items-center gap-1.5 text-sm font-medium text-brand"
      @click="router.back()"
    >
      <ArrowLeft class="size-4" />
      Volver
    </button>

    <div v-if="!load" class="rounded-2xl border border-line bg-card p-8 text-center text-muted">
      Viaje no encontrado.
    </div>

    <template v-else>
      <div class="mb-4 flex flex-wrap items-start justify-between gap-3">
        <div>
          <p class="text-xs text-muted">{{ load.reference }}</p>
          <h1 class="text-xl font-bold text-navy">
            {{ loadOriginDisplay(load) }} → {{ loadDestinationDisplay(load) }}
          </h1>
        </div>
        <span
          class="rounded-full px-2.5 py-0.5 text-[11px] font-semibold"
          :class="statusBadgeClass(load.status)"
        >
          {{ load.status }}
        </span>
      </div>

      <p v-if="message" class="mb-4 rounded-xl bg-success-soft px-3 py-2 text-sm text-success">
        {{ message }}
      </p>

      <!-- Progress -->
      <section class="mb-4 rounded-2xl border border-line bg-card p-4">
        <h2 class="mb-3 text-sm font-semibold text-navy">Progreso</h2>
        <ol class="space-y-2">
          <li
            v-for="(st, i) in carrierProgressStatuses"
            :key="st"
            class="flex items-center gap-3 text-sm"
            :class="
              LOAD_STATUSES.indexOf(load.status) >= LOAD_STATUSES.indexOf(st)
                ? 'text-navy font-medium'
                : 'text-muted'
            "
          >
            <span
              class="flex size-6 items-center justify-center rounded-full text-[11px] font-bold"
              :class="
                load.status === st
                  ? 'bg-brand text-white'
                  : LOAD_STATUSES.indexOf(load.status) > LOAD_STATUSES.indexOf(st)
                    ? 'bg-success text-white'
                    : 'bg-background border border-line text-muted'
              "
            >
              {{ i + 1 }}
            </span>
            {{ st }}
          </li>
        </ol>
        <button
          v-if="nextStatus"
          type="button"
          class="cc-btn mt-4 h-10 text-sm"
          :disabled="busy"
          @click="advance"
        >
          Marcar: {{ nextStatus }}
        </button>
      </section>

      <section class="mb-4 rounded-2xl border border-line bg-card p-4">
        <h2 class="mb-3 text-sm font-semibold text-navy">Detalle</h2>
        <dl class="space-y-2 text-sm">
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Recolección</dt>
            <dd>{{ formatDate(load.pickupDate) }}</dd>
          </div>
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Entrega</dt>
            <dd>{{ formatDate(load.deliveryDate) }}</dd>
          </div>
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Equipo</dt>
            <dd>{{ load.equipmentType }}</dd>
          </div>
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Tarifa</dt>
            <dd class="font-semibold text-navy">
              {{
                formatMoney(
                  load.assignedPriceSinIVA ?? load.offeredPrice,
                  load.currency,
                )
              }}
            </dd>
          </div>
          <div v-if="load.trackingUrl" class="flex justify-between gap-4">
            <dt class="text-muted">Rastreo</dt>
            <dd>
              <a
                :href="load.trackingUrl"
                target="_blank"
                rel="noopener"
                class="text-brand underline"
              >
                Abrir enlace
              </a>
            </dd>
          </div>
        </dl>
      </section>

      <section
        v-if="showPrivate"
        class="mb-4 rounded-2xl border border-line bg-card p-4"
      >
        <h2 class="mb-3 text-sm font-semibold text-navy">Información operativa</h2>
        <dl class="space-y-2 text-sm">
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Contacto</dt>
            <dd>{{ load.clientContactName || '—' }}</dd>
          </div>
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Teléfono</dt>
            <dd>
              <a
                v-if="load.clientContactPhone"
                :href="`tel:${load.clientContactPhone}`"
                class="text-brand"
              >
                {{ load.clientContactPhone }}
              </a>
              <span v-else>—</span>
            </dd>
          </div>
          <div>
            <dt class="text-muted">Dirección origen</dt>
            <dd class="mt-1">{{ load.exactPickupAddress || '—' }}</dd>
          </div>
          <div>
            <dt class="text-muted">Dirección destino</dt>
            <dd class="mt-1">{{ load.exactDeliveryAddress || '—' }}</dd>
          </div>
        </dl>
      </section>

      <section
        v-if="load.statusHistory.length"
        class="mb-4 rounded-2xl border border-line bg-card p-4"
      >
        <h2 class="mb-3 text-sm font-semibold text-navy">Historial</h2>
        <ul class="space-y-2 text-sm">
          <li
            v-for="sc in [...load.statusHistory].reverse()"
            :key="sc.id"
            class="border-b border-line pb-2 last:border-0"
          >
            <p class="font-medium text-navy">{{ sc.status }}</p>
            <p class="text-xs text-muted">
              {{ sc.changedByName }} · {{ formatDate(sc.changedAt) }}
            </p>
          </li>
        </ul>
      </section>
    </template>
  </div>
</template>
