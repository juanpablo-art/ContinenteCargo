<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { Truck } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import LoadCard from '@/components/LoadCard.vue';
import EmptyState from '@/components/EmptyState.vue';
import {
  ASSIGNMENT_MODES,
  EQUIPMENT_TYPES,
  loadIsOpen,
  type AssignmentMode,
  type EquipmentType,
} from '@/lib/models';

const store = useDataStore();
const router = useRouter();
const searchText = ref('');
const filterMode = ref<AssignmentMode | null>(null);
const filterEquipment = ref<EquipmentType | null>(null);
const showEquipment = ref(false);

const filteredLoads = computed(() => {
  const q = searchText.value.trim().toLowerCase();
  return store
    .loadsForCurrentUser()
    .filter((l) => l.status === 'Publicado' && loadIsOpen(l))
    .filter((load) => {
      if (filterMode.value && load.assignmentMode !== filterMode.value) return false;
      if (filterEquipment.value && load.equipmentType !== filterEquipment.value) return false;
      if (!q) return true;
      return (
        load.originCity.toLowerCase().includes(q) ||
        load.destinationCity.toLowerCase().includes(q) ||
        load.originState.toLowerCase().includes(q) ||
        load.destinationState.toLowerCase().includes(q) ||
        load.reference.toLowerCase().includes(q)
      );
    })
    .sort((a, b) => a.deadline.getTime() - b.deadline.getTime());
});

function openLoad(id: string) {
  void router.push({ name: 'carrier-load-detail', params: { id } });
}
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <div class="sticky top-14 z-10 border-b border-line bg-background/95 px-4 py-3 backdrop-blur md:px-6">
      <input
        v-model="searchText"
        class="cc-field py-2.5"
        placeholder="Buscar ruta o referencia…"
      />
      <div class="mt-2 flex gap-2 overflow-x-auto pb-1">
        <button
          type="button"
          class="shrink-0 rounded-full px-3 py-1.5 text-xs font-medium"
          :class="
            filterMode == null
              ? 'bg-brand text-white'
              : 'border border-line bg-card text-muted'
          "
          @click="filterMode = null"
        >
          Todos
        </button>
        <button
          v-for="mode in ASSIGNMENT_MODES"
          :key="mode"
          type="button"
          class="shrink-0 rounded-full px-3 py-1.5 text-xs font-medium"
          :class="
            filterMode === mode
              ? 'bg-brand text-white'
              : 'border border-line bg-card text-muted'
          "
          @click="filterMode = filterMode === mode ? null : mode"
        >
          {{ mode }}
        </button>
        <button
          type="button"
          class="shrink-0 rounded-full px-3 py-1.5 text-xs font-medium"
          :class="
            filterEquipment
              ? 'bg-brand text-white'
              : 'border border-line bg-card text-muted'
          "
          @click="showEquipment = !showEquipment"
        >
          Equipo{{ filterEquipment ? `: ${filterEquipment}` : '' }}
        </button>
      </div>
      <div v-if="showEquipment" class="mt-2 flex flex-wrap gap-2">
        <button
          type="button"
          class="rounded-lg border border-line bg-card px-2.5 py-1 text-xs"
          @click="
            filterEquipment = null;
            showEquipment = false;
          "
        >
          Todos los equipos
        </button>
        <button
          v-for="eq in EQUIPMENT_TYPES"
          :key="eq"
          type="button"
          class="rounded-lg border border-line bg-card px-2.5 py-1 text-xs"
          :class="filterEquipment === eq ? 'border-brand text-brand' : ''"
          @click="
            filterEquipment = eq;
            showEquipment = false;
          "
        >
          {{ eq }}
        </button>
      </div>
    </div>

    <div class="px-4 py-4 md:px-6">
      <EmptyState
        v-if="!filteredLoads.length"
        title="Sin cargas disponibles"
        subtitle="No hay cargas activas que coincidan con tu búsqueda."
      >
        <template #icon><Truck class="size-6" /></template>
      </EmptyState>

      <div v-else class="grid gap-3 sm:grid-cols-2">
        <button
          v-for="load in filteredLoads"
          :key="load.id"
          type="button"
          class="text-left"
          @click="openLoad(load.id)"
        >
          <LoadCard :load="load" />
        </button>
      </div>
    </div>
  </div>
</template>
