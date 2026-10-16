<script setup lang="ts">
import { computed } from 'vue';
import { CalendarDays, Container, Layers } from '@lucide/vue';
import ElapsedCounter from '@/components/ElapsedCounter.vue';
import { formatMoney, formatShortDate } from '@/lib/format';
import type { Load } from '@/lib/models';

const props = defineProps<{ load: Load }>();

const remaining = computed(() =>
  Math.max(0, props.load.unitCount - props.load.confirmedUnitCount),
);
</script>

<template>
  <RouterLink
    :to="{ name: 'admin-load-detail', params: { id: load.id } }"
    class="cc-card block p-4 transition hover:border-blue/30"
  >
    <div class="flex items-start justify-between gap-3">
      <div class="min-w-0">
        <p class="truncate text-sm font-semibold text-navy">
          {{ load.originCity }}, {{ load.originState }} → {{ load.destinationCity }}, {{ load.destinationState }}
        </p>
        <p class="mt-0.5 truncate text-xs text-muted">{{ load.reference }}</p>
      </div>
      <div class="shrink-0 text-right">
        <p class="text-[10px] font-semibold uppercase tracking-wide text-muted">Sin tomar</p>
        <ElapsedCounter :since="load.publishedAt" class="mt-0.5 text-base" />
      </div>
    </div>
    <div class="mt-3 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-muted">
      <span class="inline-flex items-center gap-1">
        <CalendarDays class="size-3.5" aria-hidden="true" />
        {{ formatShortDate(load.pickupDate) }}
      </span>
      <span class="inline-flex items-center gap-1">
        <Container class="size-3.5" aria-hidden="true" />
        {{ load.equipmentType }}
      </span>
      <span v-if="load.unitCount > 1" class="inline-flex items-center gap-1 font-medium text-orange">
        <Layers class="size-3.5" aria-hidden="true" />
        Faltan {{ remaining }} de {{ load.unitCount }}
      </span>
      <span class="font-semibold text-navy">{{ formatMoney(load.offeredPrice, load.currency) }}</span>
    </div>
  </RouterLink>
</template>
