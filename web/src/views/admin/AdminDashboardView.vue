<script setup lang="ts">
import { computed, ref } from 'vue';
import {
  Package,
  Route as RouteIcon,
  UserPlus,
  HandCoins,
  Plus,
  ChevronRight,
  Check,
  X,
  Inbox,
  Truck,
} from '@lucide/vue';
import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';
import LoadCard from '@/components/LoadCard.vue';
import StatCard from '@/components/StatCard.vue';
import StatusBadge from '@/components/StatusBadge.vue';
import EmptyState from '@/components/EmptyState.vue';
import { formatMoney, formatShortDate, initials } from '@/lib/format';
import { loadStatusIsActive } from '@/lib/models';
import { toast } from '@/lib/toast';

const auth = useAuthStore();
const store = useDataStore();
const busy = ref<string | null>(null);

const firstName = computed(() => (auth.currentUser?.name || '').split(' ')[0]);
const greeting = computed(() => {
  const h = new Date().getHours();
  if (h < 12) return 'Buenos días';
  if (h < 19) return 'Buenas tardes';
  return 'Buenas noches';
});

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

const attentionCount = computed(
  () => pendingCounterOffers.value.length + pendingApprovals.value.length,
);

async function run(id: string, action: () => Promise<unknown>, ok: string) {
  busy.value = id;
  try {
    await action();
    toast.success(ok);
  } catch (e) {
    toast.error('No se pudo completar la acción', e instanceof Error ? e.message : undefined);
  } finally {
    busy.value = null;
  }
}
</script>

<template>
  <div class="cc-page">
    <header class="mb-6 flex flex-wrap items-end justify-between gap-4 md:mb-8">
      <div>
        <p class="text-sm font-medium text-muted">{{ greeting }}, {{ firstName }}</p>
        <h1 class="cc-h1 mt-0.5">Panel de operación</h1>
      </div>
      <RouterLink :to="{ name: 'admin-load-new' }" class="cc-btn w-auto px-5">
        <Plus class="size-4" aria-hidden="true" />
        Publicar carga
      </RouterLink>
    </header>

    <div class="grid grid-cols-2 gap-3 md:gap-4 lg:grid-cols-4">
      <StatCard
        label="Cargas abiertas"
        :value="openLoads.length"
        :icon="Package"
        tone="blue"
        :to="{ name: 'admin-loads' }"
        hint="Publicadas y en espera"
      />
      <StatCard
        label="Viajes activos"
        :value="activeTrips.length"
        :icon="RouteIcon"
        tone="success"
        hint="Asignados o en ruta"
      />
      <StatCard
        label="Contra-ofertas"
        :value="pendingCounterOffers.length"
        :icon="HandCoins"
        :tone="pendingCounterOffers.length ? 'orange' : 'navy'"
        hint="Esperan tu aprobación"
      />
      <StatCard
        label="Registros nuevos"
        :value="pendingApprovals.length"
        :icon="UserPlus"
        :tone="pendingApprovals.length ? 'orange' : 'navy'"
        :to="{ name: 'admin-carriers' }"
        :hint="availableUnits === 1 ? '1 unidad disponible' : `${availableUnits} unidades disponibles`"
      />
    </div>

    <div class="mt-8 grid gap-8 lg:grid-cols-[minmax(0,1fr)_360px]">
      <div class="min-w-0 space-y-8">
        <!-- Needs attention -->
        <section v-if="attentionCount">
          <div class="mb-3 flex items-center gap-2">
            <h2 class="cc-h2">Requiere tu atención</h2>
            <span class="cc-badge bg-orange text-white">{{ attentionCount }}</span>
          </div>
          <div class="cc-card divide-y divide-line overflow-hidden">
            <div
              v-for="item in pendingCounterOffers"
              :key="item.offer.id"
              class="flex flex-wrap items-center gap-3 p-4 sm:flex-nowrap"
            >
              <span class="cc-icon-tile bg-orange-soft text-orange">
                <HandCoins class="size-[18px]" aria-hidden="true" />
              </span>
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-semibold text-navy">
                  {{ item.offer.carrierName }}
                  <span class="font-normal text-muted">&nbsp;propone&nbsp;</span>
                  <span class="cc-money">{{
                    formatMoney(item.offer.proposedPrice ?? item.offer.amount, item.offer.currency)
                  }}</span>
                  <span class="font-normal text-muted">&nbsp;/ ud</span>
                </p>
                <p class="mt-0.5 truncate text-xs text-muted">
                  Contra-oferta · {{ item.load?.reference ?? 'Carga' }} ·
                  {{ item.offer.availableUnitCount }}
                  {{ item.offer.availableUnitCount === 1 ? 'unidad' : 'unidades' }}
                  <template v-if="item.load">
                    · Precio publicado {{ formatMoney(item.load.offeredPrice, item.load.currency) }}
                  </template>
                </p>
              </div>
              <div class="flex w-full gap-2 sm:w-auto">
                <button
                  type="button"
                  class="cc-btn-secondary h-9 flex-1 px-3 text-[13px] text-danger sm:w-auto"
                  :disabled="busy === item.offer.id"
                  @click="run(item.offer.id, () => store.rejectCounterOffer(item.offer.id), 'Contra-oferta rechazada')"
                >
                  <X class="size-4" aria-hidden="true" /> Rechazar
                </button>
                <button
                  type="button"
                  class="cc-btn-success h-9 flex-1 px-3 text-[13px] sm:w-auto"
                  :disabled="busy === item.offer.id"
                  @click="run(item.offer.id, () => store.approveCounterOffer(item.offer.id), 'Contra-oferta aprobada')"
                >
                  <Check class="size-4" aria-hidden="true" /> Aprobar
                </button>
              </div>
            </div>

            <div
              v-for="user in pendingApprovals"
              :key="user.uuid"
              class="flex flex-wrap items-center gap-3 p-4 sm:flex-nowrap"
            >
              <span
                class="flex size-10 shrink-0 items-center justify-center rounded-full bg-navy/[0.07] text-[13px] font-bold text-navy"
              >
                {{ initials(user.name) }}
              </span>
              <div class="min-w-0 flex-1">
                <RouterLink
                  :to="{ name: 'admin-carrier-detail', params: { id: user.uuid } }"
                  class="truncate text-sm font-semibold text-navy hover:text-brand"
                >
                  {{ user.name }}
                </RouterLink>
                <p class="mt-0.5 truncate text-xs text-muted">
                  Solicitud de registro ·
                  {{ user.role === 'carrier' ? 'Línea transportista' : 'Operador independiente' }} ·
                  {{ user.email }}
                </p>
              </div>
              <div class="flex w-full gap-2 sm:w-auto">
                <button
                  type="button"
                  class="cc-btn-secondary h-9 flex-1 px-3 text-[13px] text-danger sm:w-auto"
                  :disabled="busy === user.uuid"
                  @click="run(user.uuid, () => store.rejectCarrier(user.uuid), 'Registro rechazado')"
                >
                  <X class="size-4" aria-hidden="true" /> Rechazar
                </button>
                <button
                  type="button"
                  class="cc-btn-success h-9 flex-1 px-3 text-[13px] sm:w-auto"
                  :disabled="busy === user.uuid"
                  @click="run(user.uuid, () => store.approveCarrier(user.uuid), `${user.name} aprobado`)"
                >
                  <Check class="size-4" aria-hidden="true" /> Aprobar
                </button>
              </div>
            </div>
          </div>
        </section>

        <!-- Open loads -->
        <section>
          <div class="mb-3 flex items-center justify-between">
            <h2 class="cc-h2">Cargas publicadas</h2>
            <RouterLink :to="{ name: 'admin-loads' }" class="cc-btn-ghost -mr-3 h-8">
              Ver todas <ChevronRight class="size-4" aria-hidden="true" />
            </RouterLink>
          </div>
          <div v-if="openLoads.length" class="grid gap-3 sm:grid-cols-2">
            <LoadCard
              v-for="load in openLoads.slice(0, 4)"
              :key="load.id"
              :load="load"
              :to="`/admin/loads/${load.id}`"
            />
          </div>
          <div v-else class="cc-card">
            <EmptyState
              title="No hay cargas abiertas"
              subtitle="Publica una carga y los transportistas con cobertura recibirán el aviso al instante."
            >
              <template #icon><Inbox /></template>
              <RouterLink :to="{ name: 'admin-load-new' }" class="cc-btn w-auto px-5">
                <Plus class="size-4" aria-hidden="true" /> Publicar carga
              </RouterLink>
            </EmptyState>
          </div>
        </section>
      </div>

      <!-- Active trips -->
      <aside class="min-w-0">
        <div class="mb-3 flex items-center justify-between">
          <h2 class="cc-h2">Viajes en curso</h2>
          <span class="text-xs font-medium text-muted">{{ activeTrips.length }}</span>
        </div>
        <div class="cc-card overflow-hidden">
          <RouterLink
            v-for="load in activeTrips"
            :key="load.id"
            :to="`/admin/loads/${load.id}`"
            class="flex items-center gap-3 border-b border-line px-4 py-3.5 transition last:border-b-0 hover:bg-background/70"
          >
            <span class="cc-icon-tile size-9 bg-success-soft text-success">
              <Truck class="size-4" aria-hidden="true" />
            </span>
            <div class="min-w-0 flex-1">
              <p class="truncate text-sm font-semibold text-navy">
                {{ load.originCity }} → {{ load.destinationCity }}
              </p>
              <p class="mt-0.5 truncate text-xs text-muted">
                {{ load.reference }} · {{ formatShortDate(load.pickupDate) }}
              </p>
            </div>
            <StatusBadge :load="load" />
          </RouterLink>
          <p v-if="!activeTrips.length" class="px-4 py-10 text-center text-sm text-muted">
            Sin viajes activos por ahora.
          </p>
        </div>
      </aside>
    </div>
  </div>
</template>
