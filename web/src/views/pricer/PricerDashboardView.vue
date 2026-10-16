<script setup lang="ts">
import { computed } from 'vue';
import { BadgeCheck, Truck, ChartColumn, MapPin, ArrowLeftRight, Users } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import { loadStatusIsActive, type AppUser, type Load } from '@/lib/models';
import OpenLoadCard from '@/components/OpenLoadCard.vue';
import PageHeader from '@/components/PageHeader.vue';

const store = useDataStore();

const openLoads = computed(() => store.openLoads());
const openPreview = computed(() => openLoads.value.slice(0, 4));

const myCarriers = computed(() => store.carriersForPricer());
const myLoads = computed(() => store.loadsForPricer());

const delivered = computed(() => myLoads.value.filter((load) => load.status === 'Entregado'));
const inProgress = computed(() =>
  myLoads.value.filter((load) => loadStatusIsActive(load.status) && load.status !== 'Publicado'),
);
const cancelled = computed(() => myLoads.value.filter((load) => load.status === 'Cancelado'));

const unitsOf = (load: Load) => Math.max(1, load.confirmedUnitCount || 0);

const deliveredUnits = computed(() => delivered.value.reduce((sum, load) => sum + unitsOf(load), 0));

const completionRate = computed(() => {
  const finished = delivered.value.length + cancelled.value.length;
  if (!finished) return null;
  return delivered.value.length / finished;
});

const completionLabel = computed(() =>
  completionRate.value == null ? '—' : `${Math.round(completionRate.value * 100)}%`,
);

const completionTone = computed(() => {
  if (completionRate.value == null) return 'navy' as const;
  if (completionRate.value >= 0.8) return 'success' as const;
  return 'orange' as const;
});

const completionIconClass = computed(() => {
  if (completionTone.value === 'success') return 'text-success';
  if (completionTone.value === 'orange') return 'text-orange';
  return 'text-muted';
});

const thisMonthUnits = computed(() => {
  const now = new Date();
  return delivered.value
    .filter(
      (load) =>
        load.pickupDate.getFullYear() === now.getFullYear() &&
        load.pickupDate.getMonth() === now.getMonth(),
    )
    .reduce((sum, load) => sum + unitsOf(load), 0);
});

const monthly = computed(() => {
  const now = new Date();
  return Array.from({ length: 6 }, (_, index) => {
    const offset = 5 - index;
    const date = new Date(now.getFullYear(), now.getMonth() - offset, 1);
    const count = delivered.value
      .filter(
        (load) =>
          load.pickupDate.getFullYear() === date.getFullYear() &&
          load.pickupDate.getMonth() === date.getMonth(),
      )
      .reduce((sum, load) => sum + unitsOf(load), 0);
    const raw = new Intl.DateTimeFormat('es-MX', { month: 'short' }).format(date).replace('.', '');
    return { label: raw.charAt(0).toUpperCase() + raw.slice(1), count };
  });
});

const maxMonth = computed(() => Math.max(1, ...monthly.value.map((row) => row.count)));
const chartEmpty = computed(() => monthly.value.every((row) => row.count === 0));

const statusTotal = computed(
  () => delivered.value.length + inProgress.value.length + cancelled.value.length,
);

function share(count: number) {
  if (!statusTotal.value) return '0%';
  return `${(count / statusTotal.value) * 100}%`;
}

const countedLoads = computed(() => myLoads.value.filter((load) => load.status !== 'Cancelado'));

const topOrigins = computed(() => {
  const freq = new Map<string, number>();
  for (const load of countedLoads.value) {
    freq.set(load.originState, (freq.get(load.originState) ?? 0) + unitsOf(load));
  }
  return [...freq.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([state, count]) => ({ state, count }));
});

const topRoutes = computed(() => {
  const freq = new Map<string, number>();
  for (const load of countedLoads.value) {
    const route = `${load.originState} → ${load.destinationState}`;
    freq.set(route, (freq.get(route) ?? 0) + 1);
  }
  return [...freq.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([route, count]) => ({ route, count }));
});

const topCarriers = computed(() =>
  myCarriers.value
    .map((carrier) => ({
      carrier,
      count: myLoads.value.filter(
        (load) =>
          load.confirmedCarrierIds.includes(carrier.uuid) || load.assignedCarrierId === carrier.uuid,
      ).length,
    }))
    .filter((row) => row.count > 0)
    .sort((a, b) => b.count - a.count)
    .slice(0, 5),
);

const originMax = computed(() => topOrigins.value[0]?.count ?? 1);

function initial(carrier: AppUser) {
  return carrier.name.trim().charAt(0).toUpperCase() || '?';
}
</script>

<template>
  <div class="cc-page">
    <PageHeader title="Dashboard" subtitle="Cargas publicadas sin transportista y el avance de los tuyos" />

    <section class="mb-5">
      <div class="mb-2 flex items-end justify-between gap-3">
        <h2 class="text-sm font-semibold text-navy">Por cubrir</h2>
        <RouterLink
          v-if="openLoads.length"
          :to="{ name: 'pricer-loads' }"
          class="text-xs font-semibold text-brand"
        >
          Ver las {{ openLoads.length }}
        </RouterLink>
      </div>
      <p v-if="!openLoads.length" class="cc-card px-4 py-5 text-sm text-muted">
        Ninguna carga publicada está esperando transportista.
      </p>
      <div v-else class="space-y-2">
        <OpenLoadCard v-for="load in openPreview" :key="load.id" :load="load" />
      </div>
    </section>

    <div class="grid grid-cols-3 gap-2 sm:gap-3">
      <article class="cc-card min-w-0 p-3 sm:p-4">
        <BadgeCheck class="size-5 text-success" aria-hidden="true" />
        <p class="mt-2 text-2xl font-bold leading-none tabular-nums text-navy">{{ thisMonthUnits }}</p>
        <p class="mt-2 text-[11px] font-semibold leading-tight text-muted">Este mes</p>
        <p class="text-[11px] leading-tight text-muted/80">cargas cerradas</p>
      </article>
      <article class="cc-card min-w-0 p-3 sm:p-4">
        <Truck class="size-5 text-brand" aria-hidden="true" />
        <p class="mt-2 text-2xl font-bold leading-none tabular-nums text-navy">{{ inProgress.length }}</p>
        <p class="mt-2 text-[11px] font-semibold leading-tight text-muted">En progreso</p>
        <p class="text-[11px] leading-tight text-muted/80">activas ahora</p>
      </article>
      <article class="cc-card min-w-0 p-3 sm:p-4">
        <ChartColumn class="size-5" :class="completionIconClass" aria-hidden="true" />
        <p class="mt-2 text-2xl font-bold leading-none tabular-nums text-navy">{{ completionLabel }}</p>
        <p class="mt-2 text-[11px] font-semibold leading-tight text-muted">Cumplimiento</p>
        <p class="text-[11px] leading-tight text-muted/80">entregas exitosas</p>
      </article>
    </div>

    <section class="cc-card mt-4 p-4 md:p-5">
      <h2 class="flex items-center gap-2 text-sm font-semibold text-navy">
        <ChartColumn class="size-4 text-brand" aria-hidden="true" />
        Tendencia mensual
      </h2>
      <div
        v-if="chartEmpty"
        class="flex h-40 flex-col items-center justify-center gap-2 text-sm text-muted"
      >
        <ChartColumn class="size-10 text-line" aria-hidden="true" />
        Sin cargas cerradas aún
      </div>
      <div v-else class="mt-4 flex h-52 items-end gap-2 sm:gap-3">
        <div v-for="row in monthly" :key="row.label" class="flex min-w-0 flex-1 flex-col items-center gap-1.5">
          <span class="text-[11px] font-bold tabular-nums text-navy">{{ row.count || '' }}</span>
          <div class="flex h-36 w-full items-end">
            <div
              class="w-full rounded-t-lg bg-gradient-to-t from-brand to-blue"
              :style="{ height: row.count ? `${Math.max(8, (row.count / maxMonth) * 144)}px` : '0px' }"
            />
          </div>
          <span class="truncate text-[11px] text-muted">{{ row.label }}</span>
        </div>
      </div>
    </section>

    <section class="cc-card mt-4 p-4 md:p-5">
      <h2 class="flex items-center gap-2 text-sm font-semibold text-navy">
        <ChartColumn class="size-4 text-brand" aria-hidden="true" />
        Estado de cargas
      </h2>
      <div class="mt-4 flex h-4 overflow-hidden rounded-full bg-background">
        <div class="bg-success" :style="{ width: share(delivered.length) }" />
        <div class="bg-orange" :style="{ width: share(inProgress.length) }" />
        <div class="bg-danger/80" :style="{ width: share(cancelled.length) }" />
      </div>
      <div class="mt-3 flex flex-wrap gap-x-4 gap-y-2 text-xs text-muted">
        <span class="inline-flex items-center gap-1.5">
          <span class="size-2 rounded-full bg-success" />
          {{ delivered.length }} entregadas
        </span>
        <span class="inline-flex items-center gap-1.5">
          <span class="size-2 rounded-full bg-orange" />
          {{ inProgress.length }} en progreso
        </span>
        <span class="inline-flex items-center gap-1.5">
          <span class="size-2 rounded-full bg-danger/80" />
          {{ cancelled.length }} canceladas
        </span>
      </div>
      <p v-if="deliveredUnits" class="mt-3 flex items-center gap-1.5 text-xs text-muted">
        <Truck class="size-3.5 text-brand" aria-hidden="true" />
        {{ deliveredUnits }} unidades totales entregadas
      </p>
    </section>

    <section v-if="topOrigins.length" class="cc-card mt-4 p-4 md:p-5">
      <h2 class="flex items-center gap-2 text-sm font-semibold text-navy">
        <MapPin class="size-4 text-brand" aria-hidden="true" />
        Principales orígenes
      </h2>
      <ul class="mt-4 space-y-3">
        <li v-for="item in topOrigins" :key="item.state" class="flex items-center gap-3">
          <span class="w-28 shrink-0 truncate text-sm text-ink">{{ item.state }}</span>
          <span class="h-3.5 min-w-0 flex-1 overflow-hidden rounded-full bg-background">
            <span
              class="block h-full rounded-full bg-gradient-to-r from-brand to-blue"
              :style="{ width: `${Math.max(8, (item.count / originMax) * 100)}%` }"
            />
          </span>
          <span class="w-7 text-right text-xs font-semibold tabular-nums text-navy">{{ item.count }}</span>
        </li>
      </ul>
    </section>

    <section v-if="topRoutes.length" class="cc-card mt-4 p-4 md:p-5">
      <h2 class="flex items-center gap-2 text-sm font-semibold text-navy">
        <ArrowLeftRight class="size-4 text-brand" aria-hidden="true" />
        Rutas frecuentes
      </h2>
      <ol class="mt-2">
        <li
          v-for="(item, index) in topRoutes"
          :key="item.route"
          class="flex items-center gap-3 border-b border-line/70 py-2.5 last:border-0"
        >
          <span class="flex size-5 shrink-0 items-center justify-center rounded-full bg-brand text-[11px] font-bold text-white">
            {{ index + 1 }}
          </span>
          <span class="min-w-0 flex-1 truncate text-sm text-ink">{{ item.route }}</span>
          <span class="text-sm font-bold tabular-nums text-navy">{{ item.count }}</span>
          <span class="text-xs text-muted">{{ item.count === 1 ? 'viaje' : 'viajes' }}</span>
        </li>
      </ol>
    </section>

    <section v-if="topCarriers.length" class="cc-card mt-4 p-4 md:p-5">
      <h2 class="flex items-center gap-2 text-sm font-semibold text-navy">
        <Users class="size-4 text-brand" aria-hidden="true" />
        Mis transportistas
      </h2>
      <ul class="mt-2">
        <li
          v-for="item in topCarriers"
          :key="item.carrier.uuid"
          class="flex items-center gap-3 border-b border-line/70 py-2.5 last:border-0"
        >
          <span class="flex size-9 shrink-0 items-center justify-center rounded-full bg-blue-soft text-sm font-bold text-brand">
            {{ initial(item.carrier) }}
          </span>
          <span class="min-w-0 flex-1">
            <span class="block truncate text-sm font-semibold text-navy">{{ item.carrier.name }}</span>
            <span class="block truncate text-xs text-muted">{{ item.carrier.phone }}</span>
          </span>
          <span class="text-right">
            <span class="block text-lg font-bold leading-none tabular-nums text-navy">{{ item.count }}</span>
            <span class="text-[11px] text-muted">{{ item.count === 1 ? 'carga' : 'cargas' }}</span>
          </span>
        </li>
      </ul>
    </section>
  </div>
</template>
