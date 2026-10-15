<script setup lang="ts">
import { computed } from 'vue';
import {
  loadDestinationDisplay,
  loadIsFull,
  loadIsOpen,
  loadOriginDisplay,
  type Load,
} from '@/lib/models';
import {
  deadlineTone,
  formatMoney,
  formatShortDate,
  statusBadgeClass,
  timeRemaining,
} from '@/lib/format';

const props = withDefaults(
  defineProps<{
    load: Load;
    to?: string;
    showAssignmentBadge?: boolean;
    showPrice?: boolean;
  }>(),
  { showAssignmentBadge: true, showPrice: true },
);

const unitsLabel = computed(() => {
  const load = props.load;
  if (load.unitCount > 1) {
    const remaining = load.unitCount - load.confirmedUnitCount;
    if (load.confirmedUnitCount > 0 && !loadIsFull(load)) {
      return `${remaining} de ${load.unitCount} disponibles`;
    }
    return `${load.unitCount} unidades`;
  }
  return '1 unidad';
});

const deadlineClass = computed(() => {
  const tone = deadlineTone(props.load.deadline);
  if (tone === 'danger') return 'text-danger';
  if (tone === 'warn') return 'text-orange';
  return 'text-muted';
});
</script>

<template>
  <component
    :is="to ? 'router-link' : 'article'"
    :to="to"
    class="block overflow-hidden rounded-2xl border border-line bg-card shadow-sm transition hover:border-blue/30 hover:shadow-md"
  >
    <div class="flex items-start justify-between gap-3 px-4 pt-4">
      <div class="min-w-0">
        <p class="text-xs text-muted">{{ load.reference }}</p>
        <p class="mt-0.5 text-sm font-semibold text-navy">
          {{ loadOriginDisplay(load) }} → {{ loadDestinationDisplay(load) }}
        </p>
      </div>
      <span
        class="shrink-0 rounded-full px-2.5 py-0.5 text-[11px] font-semibold"
        :class="statusBadgeClass(load.status)"
      >
        {{ load.status }}
      </span>
    </div>

    <div class="mt-3 grid grid-cols-2 gap-2 px-4">
      <div class="rounded-lg bg-background px-2.5 py-2 text-xs text-ink">
        {{ formatShortDate(load.pickupDate) }}
      </div>
      <div class="rounded-lg bg-background px-2.5 py-2 text-xs text-ink truncate">
        {{ load.equipmentType }}
      </div>
      <div class="rounded-lg bg-background px-2.5 py-2 text-xs text-ink">
        {{ Math.round(load.weightKg).toLocaleString('es-MX') }} kg
      </div>
      <div class="rounded-lg bg-background px-2.5 py-2 text-xs text-ink">
        {{ unitsLabel }}
      </div>
    </div>

    <div
      v-if="load.unitCount > 1 && load.confirmedUnitCount > 0 && !loadIsFull(load)"
      class="mt-2 flex items-center justify-between gap-2 bg-orange-soft/60 px-4 py-1.5 text-xs"
    >
      <span class="font-semibold text-success"
        >{{ load.confirmedUnitCount }}/{{ load.unitCount }} asignadas</span
      >
      <span class="text-orange"
        >{{ load.unitCount - load.confirmedUnitCount }} restantes</span
      >
    </div>

    <div class="mt-3 flex items-end justify-between gap-3 border-t border-line px-4 py-3">
      <div>
        <p class="text-base font-bold text-navy">
          <template v-if="load.unitCount > 1">
            {{ formatMoney(load.offeredPrice, load.currency) }} / unidad
          </template>
          <template v-else>
            {{ formatMoney(load.offeredPrice, load.currency) }}
          </template>
        </p>
        <p v-if="load.includesVAT" class="text-[11px] text-success">IVA incluido</p>
      </div>
      <span
        v-if="showAssignmentBadge"
        class="rounded-lg bg-blue-soft px-2 py-1 text-[11px] font-medium text-blue-ink"
      >
        {{ load.assignmentMode }}
      </span>
    </div>

    <p
      v-if="loadIsOpen(load)"
      class="px-4 pb-3 text-xs"
      :class="deadlineClass"
    >
      {{ timeRemaining(load.deadline) }}
    </p>
  </component>
</template>
