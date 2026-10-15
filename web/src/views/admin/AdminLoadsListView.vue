<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { Plus, Truck } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import LoadCard from '@/components/LoadCard.vue';
import EmptyState from '@/components/EmptyState.vue';
import type { LoadStatus } from '@/lib/models';

const store = useDataStore();
const router = useRouter();
const filter = ref<'all' | 'open' | 'active' | 'done'>('all');

const filtered = computed(() => {
  let list = [...store.loads];
  if (filter.value === 'open') list = list.filter((l) => l.status === 'Publicado');
  else if (filter.value === 'active') {
    list = list.filter(
      (l) =>
        l.status !== 'Publicado' &&
        l.status !== 'Entregado' &&
        l.status !== 'Cancelado',
    );
  } else if (filter.value === 'done') {
    list = list.filter((l) => l.status === 'Entregado' || l.status === 'Cancelado');
  }
  return list.sort((a, b) => b.publishedAt.getTime() - a.publishedAt.getTime());
});

const chips: { id: typeof filter.value; label: string }[] = [
  { id: 'all', label: 'Todas' },
  { id: 'open', label: 'Abiertas' },
  { id: 'active', label: 'En curso' },
  { id: 'done', label: 'Cerradas' },
];

function openLoad(id: string) {
  void router.push({ name: 'admin-load-detail', params: { id } });
}
</script>

<template>
  <div class="mx-auto max-w-5xl px-4 py-5 md:px-6">
    <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
      <h1 class="text-xl font-bold text-navy">Cargas</h1>
      <RouterLink
        :to="{ name: 'admin-load-new' }"
        class="inline-flex h-10 items-center gap-2 rounded-[10px] bg-brand px-4 text-sm font-semibold text-white hover:bg-blue-ink"
      >
        <Plus class="size-4" />
        Publicar
      </RouterLink>
    </div>

    <div class="mb-4 flex flex-wrap gap-2">
      <button
        v-for="chip in chips"
        :key="chip.id"
        type="button"
        class="rounded-full px-3 py-1.5 text-xs font-medium transition"
        :class="
          filter === chip.id
            ? 'bg-brand text-white'
            : 'border border-line bg-card text-muted hover:text-navy'
        "
        @click="filter = chip.id"
      >
        {{ chip.label }}
      </button>
    </div>

    <EmptyState
      v-if="!filtered.length"
      title="Sin cargas"
      subtitle="No hay cargas en este filtro. Publica una nueva carga."
    >
      <template #icon><Truck class="size-6" /></template>
    </EmptyState>

    <div v-else class="grid gap-3 sm:grid-cols-2">
      <button
        v-for="load in filtered"
        :key="load.id"
        type="button"
        class="text-left"
        @click="openLoad(load.id)"
      >
        <LoadCard :load="load" />
      </button>
    </div>
  </div>
</template>
