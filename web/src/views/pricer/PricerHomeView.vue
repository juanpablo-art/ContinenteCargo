<script setup lang="ts">
import { computed, ref } from 'vue';
import { Calendar, FileText, Package, Search, User } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import { loadAwaitingCarrier, loadStatusIsActive, type Load } from '@/lib/models';
import { formatDateTime } from '@/lib/format';
import OpenLoadCard from '@/components/OpenLoadCard.vue';
import PageHeader from '@/components/PageHeader.vue';
import StatusBadge from '@/components/StatusBadge.vue';
import EmptyState from '@/components/EmptyState.vue';

const store = useDataStore();
const search = ref('');

const openLoads = computed(() => {
  const q = search.value.trim().toLowerCase();
  return store.openLoads().filter((load) => {
    if (!q) return true;
    return [load.reference, load.originCity, load.originState, load.destinationCity, load.destinationState]
      .join(' ')
      .toLowerCase()
      .includes(q);
  });
});

const myLoads = computed(() =>
  store
    .loadsForPricer()
    .filter((load) => !loadAwaitingCarrier(load))
    .slice()
    .sort((a, b) => b.pickupDate.getTime() - a.pickupDate.getTime()),
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

const waitingCount = computed(() => store.openLoads().length);

function carrierName(load: Load): string {
  const id = load.confirmedCarrierIds[0] ?? load.assignedCarrierId;
  if (!id) return '';
  return store.users.find((user) => user.uuid === id)?.name ?? '';
}
</script>

<template>
  <div class="cc-page">
    <PageHeader
      title="Por cubrir"
      :subtitle="
        waitingCount === 1
          ? '1 carga publicada todavía sin transportista'
          : `${waitingCount} cargas publicadas todavía sin transportista`
      "
    />

    <label class="relative mb-4 block">
      <Search class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted" />
      <input
        v-model="search"
        type="search"
        class="cc-field pl-10"
        placeholder="Buscar ruta o referencia"
      />
    </label>

    <div v-if="!store.loadsReady" class="space-y-2">
      <div v-for="n in 3" :key="n" class="cc-card h-24 animate-pulse bg-background" />
    </div>

    <div v-else-if="!openLoads.length" class="cc-card">
      <EmptyState
        :title="search ? 'Sin resultados' : 'Nada por cubrir'"
        :subtitle="
          search
            ? 'Prueba con otra ciudad o referencia.'
            : 'Cuando se publique una carga y nadie la tome, aparecerá aquí para todos los pricers.'
        "
      >
        <template #icon><Package /></template>
      </EmptyState>
    </div>

    <div v-else class="space-y-2">
      <OpenLoadCard v-for="load in openLoads" :key="load.id" :load="load" />
    </div>

    <section v-if="myLoads.length" class="mt-8">
      <h2 class="mb-1 text-sm font-semibold text-navy">De mis transportistas</h2>
      <p class="mb-3 text-xs text-muted">Cargas que ya tomó alguien de tu cartera.</p>
      <div class="space-y-6">
        <section v-for="section in sections" v-show="section.loads.length" :key="section.title">
          <h3 class="mb-2 text-sm font-semibold text-muted">{{ section.title }}</h3>
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
                    {{ load.originCity }}, {{ load.originState }} → {{ load.destinationCity }},
                    {{ load.destinationState }}
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
    </section>
  </div>
</template>
