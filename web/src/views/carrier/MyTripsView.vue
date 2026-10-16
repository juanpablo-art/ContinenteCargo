<script setup lang="ts">
import { computed, ref } from 'vue';
import { Route as RouteIcon, CalendarDays, Container, ChevronRight } from '@lucide/vue';
import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';
import EmptyState from '@/components/EmptyState.vue';
import PageHeader from '@/components/PageHeader.vue';
import StatusBadge from '@/components/StatusBadge.vue';
import TripProgress from '@/components/TripProgress.vue';
import { loadStatusIsActive, unitsTakenByCarrier } from '@/lib/models';
import { formatMoney, formatShortDate } from '@/lib/format';

const auth = useAuthStore();
const store = useDataStore();
const tab = ref<'active' | 'past'>('active');

function unitsLabel(loadId: string, unitCount: number) {
  const carrierId = auth.currentUser?.uuid;
  if (!carrierId || unitCount <= 1) return '';
  const load = store.loads.find((item) => item.id === loadId);
  if (!load) return '';
  const taken = unitsTakenByCarrier(load, store.offers, carrierId);
  if (taken <= 0) return '';
  return `${taken} de ${unitCount} unidades`;
}

const trips = computed(() =>
  store
    .myTrips()
    .slice()
    .sort((a, b) => b.pickupDate.getTime() - a.pickupDate.getTime()),
);

const active = computed(() => trips.value.filter((t) => loadStatusIsActive(t.status)));
const past = computed(() => trips.value.filter((t) => !loadStatusIsActive(t.status)));
const shown = computed(() => (tab.value === 'active' ? active.value : past.value));
</script>

<template>
  <div class="cc-page">
    <PageHeader title="Mis viajes" subtitle="Da seguimiento y actualiza el estatus de tus cargas" />

    <div class="mb-5 inline-flex rounded-xl border border-line bg-card p-1 shadow-card">
      <button
        v-for="t in [
          { id: 'active', label: 'En curso', n: active.length },
          { id: 'past', label: 'Historial', n: past.length },
        ] as const"
        :key="t.id"
        type="button"
        class="inline-flex h-9 items-center gap-2 rounded-lg px-4 text-sm font-semibold transition"
        :class="tab === t.id ? 'bg-navy text-white shadow-sm' : 'text-muted hover:text-navy'"
        @click="tab = t.id"
      >
        {{ t.label }}
        <span
          class="rounded-full px-1.5 text-[11px] tabular-nums"
          :class="tab === t.id ? 'bg-white/20' : 'bg-background'"
        >
          {{ t.n }}
        </span>
      </button>
    </div>

    <div v-if="!shown.length" class="cc-card">
      <EmptyState
        :title="tab === 'active' ? 'Sin viajes en curso' : 'Aún no hay historial'"
        subtitle="Cuando confirmes o ganes una carga, aparecerá aquí."
      >
        <template #icon><RouteIcon /></template>
        <RouterLink v-if="tab === 'active'" :to="{ name: 'carrier-home' }" class="cc-btn w-auto px-5">
          Buscar cargas
        </RouterLink>
      </EmptyState>
    </div>

    <div v-else class="grid gap-3 md:grid-cols-2">
      <RouterLink
        v-for="load in shown"
        :key="load.id"
        :to="{ name: 'carrier-trip-detail', params: { id: load.id } }"
        class="cc-card-interactive group p-4 md:p-5"
      >
        <div class="flex items-center justify-between gap-3">
          <span class="font-mono text-[11.5px] font-medium tracking-wide text-muted">
            {{ load.reference }}
          </span>
          <StatusBadge :status="load.status" />
        </div>
        <div class="mt-3 flex items-center gap-2">
          <p class="min-w-0 flex-1 truncate text-[16px] font-semibold text-navy">
            {{ load.originCity }}
            <span class="px-1 text-muted">→</span>
            {{ load.destinationCity }}
          </p>
          <ChevronRight class="size-5 shrink-0 text-muted transition group-hover:translate-x-0.5 group-hover:text-brand" />
        </div>
        <TripProgress class="mt-3" :status="load.status" />
        <div class="mt-3.5 flex flex-wrap items-center justify-between gap-2 text-[12.5px] text-muted">
          <div class="flex flex-wrap gap-x-4 gap-y-1">
            <span class="inline-flex items-center gap-1.5">
              <CalendarDays class="size-3.5" aria-hidden="true" />
              {{ formatShortDate(load.pickupDate) }}
            </span>
            <span class="inline-flex items-center gap-1.5">
              <Container class="size-3.5" aria-hidden="true" />
              {{ load.equipmentType }}
            </span>
            <span v-if="unitsLabel(load.id, load.unitCount)" class="font-semibold text-brand">
              {{ unitsLabel(load.id, load.unitCount) }}
            </span>
          </div>
          <span class="cc-money text-sm">{{ formatMoney(load.offeredPrice, load.currency) }}</span>
        </div>
      </RouterLink>
    </div>
  </div>
</template>
