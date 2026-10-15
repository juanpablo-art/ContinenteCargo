<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { FileText, Map, UserPlus, Truck, CircleDollarSign, AlertTriangle } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import LoadCard from '@/components/LoadCard.vue';
import { formatMoney, formatShortDate, statusBadgeClass } from '@/lib/format';
import { loadStatusIsActive } from '@/lib/models';

const store = useDataStore();
const router = useRouter();

const openLoads = computed(() =>
  store.loads
    .filter((l) => l.status === 'Publicado')
    .sort((a, b) => a.deadline.getTime() - b.deadline.getTime()),
);

const activeTrips = computed(() =>
  store.loads.filter((load) => {
    if (loadStatusIsActive(load.status) && load.status !== 'Publicado') return true;
    return load.status === 'Publicado' && load.confirmedUnitCount > 0;
  }),
);

const pendingApprovals = computed(() => store.pendingUsers());

const pendingCounterOffers = computed(() =>
  store.offers
    .filter((o) => o.status === 'PendienteAprobacion')
    .map((offer) => ({
      offer,
      load: store.loads.find((l) => l.id === offer.loadId),
    })),
);

const availableUnits = computed(
  () => store.units.filter((u) => u.status === 'Disponible').length,
);

function openLoad(id: string) {
  void router.push({ name: 'admin-load-detail', params: { id } });
}

async function approveOffer(id: string) {
  await store.approveCounterOffer(id);
}

async function rejectOffer(id: string) {
  await store.rejectCounterOffer(id);
}

async function approveUser(id: string) {
  await store.approveCarrier(id);
}

async function rejectUser(id: string) {
  await store.rejectCarrier(id);
}
</script>

<template>
  <div class="mx-auto max-w-5xl px-4 py-5 md:px-6">
    <div class="mb-5 flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 class="text-xl font-bold text-navy">Panel Continente</h1>
        <p class="text-sm text-muted">Resumen operativo en tiempo real</p>
      </div>
      <RouterLink
        :to="{ name: 'admin-load-new' }"
        class="inline-flex h-10 items-center rounded-[10px] bg-brand px-4 text-sm font-semibold text-white hover:bg-blue-ink"
      >
        Publicar carga
      </RouterLink>
    </div>

    <div class="grid grid-cols-2 gap-3 md:grid-cols-4">
      <div class="rounded-2xl border border-line bg-card p-4">
        <FileText class="mb-2 size-5 text-brand" />
        <p class="text-2xl font-bold text-navy">{{ openLoads.length }}</p>
        <p class="text-xs text-muted">Cargas abiertas</p>
      </div>
      <div class="rounded-2xl border border-line bg-card p-4">
        <Map class="mb-2 size-5 text-success" />
        <p class="text-2xl font-bold text-navy">{{ activeTrips.length }}</p>
        <p class="text-xs text-muted">Viajes activos</p>
      </div>
      <div class="rounded-2xl border border-line bg-card p-4">
        <UserPlus class="mb-2 size-5 text-orange" />
        <p class="text-2xl font-bold text-navy">{{ pendingApprovals.length }}</p>
        <p class="text-xs text-muted">Aprobaciones</p>
      </div>
      <div class="rounded-2xl border border-line bg-card p-4">
        <Truck class="mb-2 size-5 text-success" />
        <p class="text-2xl font-bold text-navy">{{ availableUnits }}</p>
        <p class="text-xs text-muted">Unidades disponibles</p>
      </div>
    </div>

    <div
      v-if="pendingCounterOffers.length"
      class="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2"
    >
      <div class="rounded-2xl border border-orange/30 bg-orange-soft/50 p-4">
        <CircleDollarSign class="mb-2 size-5 text-orange" />
        <p class="text-2xl font-bold text-navy">{{ pendingCounterOffers.length }}</p>
        <p class="text-xs text-muted">Contra-ofertas pendientes</p>
      </div>
    </div>

    <!-- Counter-offers -->
    <section v-if="pendingCounterOffers.length" class="mt-8">
      <h2 class="mb-3 text-base font-semibold text-navy">
        Contra-ofertas pendientes de aprobación
      </h2>
      <div class="space-y-3">
        <div
          v-for="item in pendingCounterOffers"
          :key="item.offer.id"
          class="rounded-2xl border border-line bg-card p-4"
        >
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div>
              <p class="font-semibold text-navy">{{ item.offer.carrierName }}</p>
              <p class="text-sm text-muted">
                {{ item.load?.reference ?? 'Carga' }}
                ·
                {{ formatMoney(item.offer.proposedPrice ?? item.offer.amount, item.offer.currency) }}
                / ud · {{ item.offer.availableUnitCount }} ud.
              </p>
            </div>
            <div class="flex gap-2">
              <button
                type="button"
                class="rounded-lg bg-success px-3 py-1.5 text-xs font-semibold text-white"
                @click="approveOffer(item.offer.id)"
              >
                Aprobar
              </button>
              <button
                type="button"
                class="rounded-lg bg-danger px-3 py-1.5 text-xs font-semibold text-white"
                @click="rejectOffer(item.offer.id)"
              >
                Rechazar
              </button>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- Open loads -->
    <section v-if="openLoads.length" class="mt-8">
      <div class="mb-3 flex items-center justify-between">
        <h2 class="text-base font-semibold text-navy">Cargas publicadas</h2>
        <RouterLink :to="{ name: 'admin-loads' }" class="text-sm font-medium text-brand">
          Ver todas
        </RouterLink>
      </div>
      <div class="flex gap-3 overflow-x-auto pb-2">
        <button
          v-for="load in openLoads"
          :key="load.id"
          type="button"
          class="w-[300px] shrink-0 text-left"
          @click="openLoad(load.id)"
        >
          <LoadCard :load="load" />
        </button>
      </div>
    </section>

    <!-- Active trips -->
    <section v-if="activeTrips.length" class="mt-8">
      <h2 class="mb-3 text-base font-semibold text-navy">Viajes en curso</h2>
      <div class="space-y-2">
        <button
          v-for="load in activeTrips"
          :key="load.id"
          type="button"
          class="flex w-full items-center justify-between gap-3 rounded-2xl border border-line bg-card px-4 py-3 text-left hover:border-blue/30"
          @click="openLoad(load.id)"
        >
          <div class="min-w-0">
            <p class="truncate text-sm font-semibold text-navy">
              {{ load.originCity }} → {{ load.destinationCity }}
            </p>
            <p class="text-xs text-muted">
              {{ load.reference }} · {{ formatShortDate(load.pickupDate) }}
            </p>
          </div>
          <span
            class="shrink-0 rounded-full px-2.5 py-0.5 text-[11px] font-semibold"
            :class="statusBadgeClass(load.status)"
          >
            {{ load.status }}
          </span>
        </button>
      </div>
    </section>

    <!-- Pending approvals -->
    <section v-if="pendingApprovals.length" class="mt-8">
      <div class="mb-3 flex items-center justify-between">
        <h2 class="text-base font-semibold text-navy">Aprobaciones de registro</h2>
        <RouterLink :to="{ name: 'admin-carriers' }" class="text-sm font-medium text-brand">
          Directorio
        </RouterLink>
      </div>
      <div class="space-y-3">
        <div
          v-for="user in pendingApprovals"
          :key="user.uuid"
          class="rounded-2xl border border-line bg-card p-4"
        >
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div>
              <p class="font-semibold text-navy">{{ user.name }}</p>
              <p class="text-sm text-muted">
                {{ user.email }} ·
                {{ user.role === 'carrier' ? 'Línea' : 'Operador' }}
              </p>
            </div>
            <div class="flex gap-2">
              <button
                type="button"
                class="rounded-lg bg-success px-3 py-1.5 text-xs font-semibold text-white"
                @click="approveUser(user.uuid)"
              >
                Aprobar
              </button>
              <button
                type="button"
                class="rounded-lg border border-line px-3 py-1.5 text-xs font-semibold text-danger"
                @click="rejectUser(user.uuid)"
              >
                Rechazar
              </button>
            </div>
          </div>
        </div>
      </div>
    </section>

    <div
      v-if="!openLoads.length && !activeTrips.length && !pendingApprovals.length"
      class="mt-10 rounded-2xl border border-dashed border-line bg-card px-6 py-12 text-center"
    >
      <AlertTriangle class="mx-auto mb-3 size-8 text-muted" />
      <p class="font-semibold text-navy">Sin actividad reciente</p>
      <p class="mt-1 text-sm text-muted">Publica una carga para empezar.</p>
    </div>
  </div>
</template>
