<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { Map } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import EmptyState from '@/components/EmptyState.vue';
import { loadDestinationDisplay, loadOriginDisplay, loadStatusIsActive } from '@/lib/models';
import { formatShortDate, statusBadgeClass } from '@/lib/format';

const store = useDataStore();
const router = useRouter();

const trips = computed(() =>
  store
    .myTrips()
    .slice()
    .sort((a, b) => b.pickupDate.getTime() - a.pickupDate.getTime()),
);

const active = computed(() => trips.value.filter((t) => loadStatusIsActive(t.status)));
const past = computed(() => trips.value.filter((t) => !loadStatusIsActive(t.status)));

function open(id: string) {
  void router.push({ name: 'carrier-trip-detail', params: { id } });
}
</script>

<template>
  <div class="cc-page">
    <h1 class="cc-h1 mb-5">Mis viajes</h1>

    <EmptyState
      v-if="!trips.length"
      title="Sin viajes"
      subtitle="Cuando confirmes o ganes una carga, aparecerá aquí."
    >
      <template #icon><Map class="size-6" /></template>
    </EmptyState>

    <template v-else>
      <section v-if="active.length" class="mb-8">
        <h2 class="cc-h2 mb-3">En curso</h2>
        <div class="space-y-2">
          <button
            v-for="load in active"
            :key="load.id"
            type="button"
            class="flex w-full items-center justify-between gap-3 cc-card-interactive px-4 py-3 text-left"
            @click="open(load.id)"
          >
            <div class="min-w-0">
              <p class="truncate text-sm font-semibold text-navy">
                {{ loadOriginDisplay(load) }} → {{ loadDestinationDisplay(load) }}
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

      <section v-if="past.length">
        <h2 class="cc-h2 mb-3">Historial</h2>
        <div class="space-y-2">
          <button
            v-for="load in past"
            :key="load.id"
            type="button"
            class="flex w-full items-center justify-between gap-3 cc-card px-4 py-3 text-left opacity-80 hover:opacity-100"
            @click="open(load.id)"
          >
            <div class="min-w-0">
              <p class="truncate text-sm font-semibold text-navy">
                {{ loadOriginDisplay(load) }} → {{ loadDestinationDisplay(load) }}
              </p>
              <p class="text-xs text-muted">{{ load.reference }}</p>
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
    </template>
  </div>
</template>
