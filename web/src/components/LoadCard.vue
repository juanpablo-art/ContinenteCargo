<script setup lang="ts">
import { computed } from 'vue';
import { CalendarDays, Clock, Container, Layers, Weight } from '@lucide/vue';
import {
  loadDestinationDisplay,
  loadIsFull,
  loadIsOpen,
  loadOriginDisplay,
  type Load,
} from '@/lib/models';
import { deadlineTone, formatMoney, formatShortDate, timeRemaining } from '@/lib/format';
import StatusBadge from '@/components/StatusBadge.vue';

const props = withDefaults(
  defineProps<{
    load: Load;
    to?: string;
    showAssignmentBadge?: boolean;
    showPrice?: boolean;
  }>(),
  { showAssignmentBadge: true, showPrice: true },
);

const isPartial = computed(
  () =>
    props.load.unitCount > 1 && props.load.confirmedUnitCount > 0 && !loadIsFull(props.load),
);

const unitsLabel = computed(() => {
  const load = props.load;
  if (load.unitCount > 1) {
    if (isPartial.value) {
      return `${load.unitCount - load.confirmedUnitCount} de ${load.unitCount} libres`;
    }
    return `${load.unitCount} unidades`;
  }
  return '1 unidad';
});

const fillPct = computed(() =>
  Math.min(100, Math.round((props.load.confirmedUnitCount / props.load.unitCount) * 100)),
);

const deadlineClass = computed(() => {
  const tone = deadlineTone(props.load.deadline);
  if (tone === 'danger') return 'bg-danger-soft text-danger';
  if (tone === 'warn') return 'bg-orange-soft text-orange';
  return 'bg-background text-muted';
});

const modeClass = computed(() => {
  switch (props.load.assignmentMode) {
    case 'Subasta Inversa':
      return 'bg-violet-50 text-violet-700';
    case 'Confirmación Manual':
      return 'bg-orange-soft text-orange';
    case 'Consolidada LTL':
      return 'bg-teal-50 text-teal-700';
    default:
      return 'bg-blue-soft text-blue-ink';
  }
});
</script>

<template>
  <component
    :is="to ? 'router-link' : 'article'"
    :to="to"
    class="group block overflow-hidden"
    :class="to ? 'cc-card-interactive' : 'cc-card'"
  >
    <div class="p-4 pb-3">
      <div class="flex items-center justify-between gap-3">
        <span class="font-mono text-[11.5px] font-medium tracking-wide text-muted">
          {{ load.reference }}
        </span>
        <StatusBadge :load="load" />
      </div>

      <div class="mt-3 flex gap-3">
        <div class="flex flex-col items-center pt-[5px]" aria-hidden="true">
          <span class="size-2.5 rounded-full border-2 border-brand bg-card" />
          <span class="my-1 w-px flex-1 bg-gradient-to-b from-brand/50 to-orange/50" />
          <span class="size-2.5 rounded-full bg-orange" />
        </div>
        <div class="min-w-0 flex-1 space-y-2.5">
          <p class="truncate text-[15px] font-semibold leading-tight text-navy">
            {{ loadOriginDisplay(load) }}
          </p>
          <p class="truncate text-[15px] font-semibold leading-tight text-navy">
            {{ loadDestinationDisplay(load) }}
          </p>
        </div>
      </div>

      <div class="mt-3.5 flex flex-wrap gap-1.5 text-[12px] font-medium text-ink/75">
        <span class="inline-flex items-center gap-1 rounded-full bg-background px-2.5 py-1">
          <CalendarDays class="size-3.5 text-muted" aria-hidden="true" />
          {{ formatShortDate(load.pickupDate) }}
        </span>
        <span class="inline-flex max-w-full items-center gap-1 rounded-full bg-background px-2.5 py-1">
          <Container class="size-3.5 shrink-0 text-muted" aria-hidden="true" />
          <span class="truncate">{{ load.equipmentType }}</span>
        </span>
        <span class="inline-flex items-center gap-1 rounded-full bg-background px-2.5 py-1">
          <Weight class="size-3.5 text-muted" aria-hidden="true" />
          {{ Math.round(load.weightKg).toLocaleString('es-MX') }} kg
        </span>
        <span class="inline-flex items-center gap-1 rounded-full bg-background px-2.5 py-1">
          <Layers class="size-3.5 text-muted" aria-hidden="true" />
          {{ unitsLabel }}
        </span>
      </div>

      <div v-if="isPartial" class="mt-3">
        <div class="flex justify-between text-[11.5px] font-medium">
          <span class="text-success">
            {{ load.confirmedUnitCount }}/{{ load.unitCount }} asignadas
          </span>
          <span class="text-orange">{{ load.unitCount - load.confirmedUnitCount }} restantes</span>
        </div>
        <div class="mt-1 h-1.5 overflow-hidden rounded-full bg-orange-soft">
          <div class="h-full rounded-full bg-success" :style="{ width: `${fillPct}%` }" />
        </div>
      </div>
    </div>

    <div class="flex items-center justify-between gap-3 border-t border-line bg-background/40 px-4 py-3">
      <div v-if="showPrice" class="min-w-0">
        <p class="cc-money text-[17px] leading-tight">
          {{ formatMoney(load.offeredPrice, load.currency) }}
          <span v-if="load.unitCount > 1" class="text-xs font-medium text-muted">/ unidad</span>
        </p>
        <p class="mt-0.5 text-[11px] font-medium" :class="load.includesVAT ? 'text-success' : 'text-muted'">
          {{ load.includesVAT ? 'IVA incluido' : 'Más IVA' }}
        </p>
      </div>
      <div class="flex flex-col items-end gap-1.5">
        <span v-if="showAssignmentBadge" class="cc-badge" :class="modeClass">
          {{ load.assignmentMode }}
        </span>
        <span
          v-if="loadIsOpen(load)"
          class="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-medium"
          :class="deadlineClass"
        >
          <Clock class="size-3" aria-hidden="true" />
          {{ timeRemaining(load.deadline) }}
        </span>
      </div>
    </div>
  </component>
</template>
