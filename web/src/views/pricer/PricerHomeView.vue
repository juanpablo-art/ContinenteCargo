<script setup lang="ts">
import { computed } from 'vue';
import { Calendar, FileText, Package, User } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import { loadStatusIsActive, type Load } from '@/lib/models';
import { formatDateTime } from '@/lib/format';
import PageHeader from '@/components/PageHeader.vue';
import StatusBadge from '@/components/StatusBadge.vue';
import EmptyState from '@/components/EmptyState.vue';

const store = useDataStore();

const myLoads = computed(() =>
  store.loadsForPricer().slice().sort((a, b) => b.pickupDate.getTime() - a.pickupDate.getTime()),
);

const sections = computed(() => [
  {
    title: 'En progreso',
    loads: myLoads.value.filter((load) => loadStatusIsActive(load.status) && load.status !== 'Publicado'),
  },
  {
    title: 'Publicadas',
    loads: myLoads.value.filter((load) => load.status === 'Publicado'),
  },
  {
    title: 'Completadas',
    loads: myLoads.value.filter((load) => load.status === 'Entregado' || load.status === 'Cancelado'),
  },
]);

function carrierName(load: Load): string {
  const id = load.confirmedCarrierIds[0] ?? load.assignedCarrierId;
  if (!id) return '';
  return store.users.find((user) => user.uuid === id)?.name ?? '';
}
</script>

<template>
  <div class="cc-page">
    <PageHeader title="Mis cargas" subtitle="Cargas de tus transportistas" />

    <div v-if="!myLoads.length" class="cc-card">
      <EmptyState
        title="Sin cargas asignadas"
        subtitle="Las cargas de tus transportistas aparecerán aquí."
      >
        <template #icon><Package /></template>
      </EmptyState>
    </div>

    <div v-else class="space-y-6">
      <section v-for="section in sections" v-show="section.loads.length" :key="section.title">
        <h2 class="mb-2 text-sm font-semibold text-muted">{{ section.title }}</h2>
        <div class="space-y-2">
          <RouterLink
            v-for="load in section.loads"
            :key="load.id"
            :to="{ name: 'admin-load-detail', params: { id: load.id } }"
            class="cc-card block p-4 transition hover:border-blue/30"
          >
            <div class="flex items-start gap-3">
              <div class="min-w-0 flex-1">
                <p class="text-sm font-semibold text-navy">
                  {{ load.originCity }}, {{ load.originState }} → {{ load.destinationCity }}, {{ load.destinationState }}
                </p>
                <p class="mt-0.5 text-xs text-muted">{{ load.reference }}</p>
              </div>
              <StatusBadge :load="load" />
            </div>
            <div class="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted">
              <span class="inline-flex items-center gap-1">
                <Calendar class="size-3.5" aria-hidden="true" />
                {{ formatDateTime(load.pickupDate) }}
              </span>
              <span v-if="carrierName(load)" class="inline-flex items-center gap-1 font-medium text-brand">
                <User class="size-3.5" aria-hidden="true" />
                {{ carrierName(load) }}
              </span>
              <span v-if="load.cartaInstruccion" class="inline-flex items-center gap-1 font-medium text-success">
                <FileText class="size-3.5" aria-hidden="true" />
                CI generada
              </span>
            </div>
          </RouterLink>
        </div>
      </section>
    </div>
  </div>
</template>
