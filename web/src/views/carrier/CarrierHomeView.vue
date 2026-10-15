<script setup lang="ts">
import { computed, ref } from 'vue';
import LoadCard from '@/components/LoadCard.vue';
import EmptyState from '@/components/EmptyState.vue';
import { useDataStore } from '@/stores/data';
import {
  ASSIGNMENT_MODES,
  EQUIPMENT_TYPES,
  loadDestinationDisplay,
  loadIsOpen,
  loadOriginDisplay,
} from '@/lib/models';

const store = useDataStore();
const q = ref('');
const mode = ref('');
const equipment = ref('');

const filtered = computed(() => {
  const query = q.value.trim().toLowerCase();
  return store
    .loadsForCurrentUser()
    .filter((l) => loadIsOpen(l))
    .filter((l) => {
      if (mode.value && l.assignmentMode !== mode.value) return false;
      if (equipment.value && l.equipmentType !== equipment.value) return false;
      if (!query) return true;
      return (
        l.reference.toLowerCase().includes(query) ||
        loadOriginDisplay(l).toLowerCase().includes(query) ||
        loadDestinationDisplay(l).toLowerCase().includes(query)
      );
    })
    .sort((a, b) => a.deadline.getTime() - b.deadline.getTime());
});
</script>

<template>
  <div class="mx-auto w-full max-w-3xl px-4 py-6 sm:px-6">
    <h1 class="text-2xl font-bold text-navy">Cargas disponibles</h1>
    <p class="mt-1 text-sm text-muted">Actualización en tiempo real</p>

    <input v-model="q" class="cc-field mt-4" placeholder="Buscar ruta o referencia…" />
    <div class="mt-2 grid gap-2 sm:grid-cols-2">
      <select v-model="mode" class="cc-field !py-2.5 text-sm">
        <option value="">Modalidad</option>
        <option v-for="m in ASSIGNMENT_MODES" :key="m" :value="m">{{ m }}</option>
      </select>
      <select v-model="equipment" class="cc-field !py-2.5 text-sm">
        <option value="">Equipo</option>
        <option v-for="e in EQUIPMENT_TYPES" :key="e" :value="e">{{ e }}</option>
      </select>
    </div>

    <div class="mt-5 space-y-3">
      <LoadCard
        v-for="load in filtered"
        :key="load.id"
        :load="load"
        :to="`/carrier/loads/${load.id}`"
      />
      <EmptyState
        v-if="!filtered.length"
        title="Sin cargas disponibles"
        subtitle="No hay cargas activas que coincidan con tu cobertura."
      />
    </div>
  </div>
</template>
