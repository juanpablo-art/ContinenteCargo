<script setup lang="ts">
import { computed } from 'vue';
import LoadCard from '@/components/LoadCard.vue';
import EmptyState from '@/components/EmptyState.vue';
import { useDataStore } from '@/stores/data';

const store = useDataStore();
const trips = computed(() =>
  [...store.myTrips()].sort((a, b) => b.pickupDate.getTime() - a.pickupDate.getTime()),
);
</script>

<template>
  <div class="mx-auto w-full max-w-3xl px-4 py-6 sm:px-6">
    <h1 class="text-2xl font-bold text-navy">Mis viajes</h1>
    <p class="mt-1 text-sm text-muted">{{ trips.length }} viajes</p>
    <div class="mt-5 space-y-3">
      <LoadCard
        v-for="load in trips"
        :key="load.id"
        :load="load"
        :to="`/carrier/trips/${load.id}`"
      />
      <EmptyState
        v-if="!trips.length"
        title="Sin viajes"
        subtitle="Cuando confirmes o te asignen una carga aparecerá aquí."
      />
    </div>
  </div>
</template>
