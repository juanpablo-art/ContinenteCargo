<script setup lang="ts">
import StatusBadge from '@/components/StatusBadge.vue';
import EmptyState from '@/components/EmptyState.vue';
import { useDataStore } from '@/stores/data';
import { formatDate } from '@/lib/format';

const store = useDataStore();
</script>

<template>
  <div class="mx-auto w-full max-w-5xl px-4 py-6 sm:px-6">
    <h1 class="text-2xl font-bold text-navy">Unidades</h1>
    <p class="mt-1 text-sm text-muted">Disponibilidad publicada por transportistas</p>
    <div class="mt-5 space-y-3">
      <div
        v-for="u in store.units"
        :key="u.id"
        class="rounded-2xl border border-line bg-card p-4"
      >
        <div class="flex justify-between gap-2">
          <div>
            <p class="font-semibold text-navy">{{ u.equipmentType }}</p>
            <p class="text-xs text-muted">
              {{ u.plates || 'Sin placas' }} · {{ u.currentLocation || '—' }}
            </p>
            <p class="text-xs text-muted">Desde {{ formatDate(u.availableFrom) }}</p>
          </div>
          <StatusBadge :status="u.status" />
        </div>
      </div>
      <EmptyState v-if="!store.units.length" title="Sin unidades" />
    </div>
  </div>
</template>
