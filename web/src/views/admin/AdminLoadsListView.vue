<script setup lang="ts">
import { computed, ref } from 'vue';
import { Plus, Package, Search } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import LoadCard from '@/components/LoadCard.vue';
import LoadCardSkeleton from '@/components/LoadCardSkeleton.vue';
import EmptyState from '@/components/EmptyState.vue';
import PageHeader from '@/components/PageHeader.vue';
import type { Load } from '@/lib/models';

type Filter = 'all' | 'open' | 'active' | 'done';

const store = useDataStore();
const filter = ref<Filter>('all');
const search = ref('');

function matches(l: Load, f: Filter) {
  if (f === 'open') return l.status === 'Publicado';
  if (f === 'active') return !['Publicado', 'Entregado', 'Cancelado'].includes(l.status);
  if (f === 'done') return l.status === 'Entregado' || l.status === 'Cancelado';
  return true;
}

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase();
  return store.loads
    .filter((l) => matches(l, filter.value))
    .filter(
      (l) =>
        !q ||
        [l.reference, l.originCity, l.originState, l.destinationCity, l.destinationState]
          .join(' ')
          .toLowerCase()
          .includes(q),
    )
    .sort((a, b) => b.publishedAt.getTime() - a.publishedAt.getTime());
});

const chips = computed(() =>
  (
    [
      { id: 'all', label: 'Todas' },
      { id: 'open', label: 'Abiertas' },
      { id: 'active', label: 'En curso' },
      { id: 'done', label: 'Cerradas' },
    ] as { id: Filter; label: string }[]
  ).map((c) => ({ ...c, count: store.loads.filter((l) => matches(l, c.id)).length })),
);
</script>

<template>
  <div class="cc-page">
    <PageHeader title="Cargas" :subtitle="`${store.loads.length} cargas en total`">
      <template #actions>
        <RouterLink :to="{ name: 'admin-load-new' }" class="cc-btn w-auto px-5">
          <Plus class="size-4" aria-hidden="true" />
          Publicar carga
        </RouterLink>
      </template>
    </PageHeader>

    <div class="mb-5 flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
      <div class="cc-scroll-x">
        <button
          v-for="chip in chips"
          :key="chip.id"
          type="button"
          class="cc-chip"
          :class="filter === chip.id && 'cc-chip-active'"
          @click="filter = chip.id"
        >
          {{ chip.label }}
          <span
            class="rounded-full px-1.5 text-[11px] font-semibold tabular-nums"
            :class="filter === chip.id ? 'bg-white/20' : 'bg-background text-muted'"
          >
            {{ chip.count }}
          </span>
        </button>
      </div>
      <label class="relative block md:w-72">
        <Search class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted" />
        <input v-model="search" type="search" class="cc-field pl-10" placeholder="Buscar ruta o referencia" />
      </label>
    </div>

    <div v-if="!store.loadsReady" class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
      <LoadCardSkeleton :count="6" />
    </div>

    <div v-else-if="!filtered.length" class="cc-card">
      <EmptyState
        title="Sin cargas en este filtro"
        :subtitle="search ? 'Prueba con otra ciudad o referencia.' : 'Cuando publiques una carga aparecerá aquí.'"
      >
        <template #icon><Package /></template>
      </EmptyState>
    </div>

    <div v-else class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
      <LoadCard
        v-for="load in filtered"
        :key="load.id"
        :load="load"
        :to="`/admin/loads/${load.id}`"
      />
    </div>
  </div>
</template>
