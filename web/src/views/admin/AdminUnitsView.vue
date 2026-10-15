<script setup lang="ts">
import { computed, ref } from 'vue';
import { Truck } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import EmptyState from '@/components/EmptyState.vue';
import { unitStatusClass } from '@/lib/format';
import type { UnitStatus } from '@/lib/models';

const store = useDataStore();
const filter = ref<'all' | UnitStatus>('all');
const search = ref('');

const units = computed(() => {
  let list = store.units.filter((u) => u.notes !== 'availability_post');
  if (filter.value !== 'all') list = list.filter((u) => u.status === filter.value);
  const q = search.value.trim().toLowerCase();
  if (q) {
    list = list.filter(
      (u) =>
        u.plates.toLowerCase().includes(q) ||
        u.trailerNumber.toLowerCase().includes(q) ||
        u.operatorName.toLowerCase().includes(q) ||
        u.currentLocation.toLowerCase().includes(q) ||
        u.equipmentType.toLowerCase().includes(q),
    );
  }
  return list;
});

function ownerName(ownerId: string) {
  return store.users.find((u) => u.uuid === ownerId || u.companyId === ownerId)?.name ?? ownerId.slice(0, 8);
}
</script>

<template>
  <div class="mx-auto max-w-5xl px-4 py-5 md:px-6">
    <h1 class="mb-1 text-xl font-bold text-navy">Unidades</h1>
    <p class="mb-4 text-sm text-muted">Disponibilidad de flota en la red</p>

    <div class="mb-4 flex flex-col gap-3 sm:flex-row">
      <input
        v-model="search"
        class="cc-field py-2.5 sm:max-w-xs"
        placeholder="Buscar placas, operador…"
      />
      <div class="flex flex-wrap gap-2">
        <button
          v-for="chip in [
            { id: 'all' as const, label: 'Todas' },
            { id: 'Disponible' as const, label: 'Disponibles' },
            { id: 'Reservada' as const, label: 'Reservadas' },
            { id: 'En viaje' as const, label: 'En viaje' },
          ]"
          :key="chip.id"
          type="button"
          class="rounded-full px-3 py-1.5 text-xs font-medium"
          :class="
            filter === chip.id
              ? 'bg-brand text-white'
              : 'border border-line bg-card text-muted'
          "
          @click="filter = chip.id"
        >
          {{ chip.label }}
        </button>
      </div>
    </div>

    <EmptyState
      v-if="!units.length"
      title="Sin unidades"
      subtitle="Aún no hay unidades registradas en la red."
    >
      <template #icon><Truck class="size-6" /></template>
    </EmptyState>

    <div v-else class="space-y-3">
      <article
        v-for="unit in units"
        :key="unit.id"
        class="rounded-2xl border border-line bg-card p-4"
      >
        <div class="flex flex-wrap items-start justify-between gap-2">
          <div>
            <p class="font-semibold text-navy">
              {{ unit.plates || unit.trailerNumber || 'Sin placas' }}
            </p>
            <p class="text-sm text-muted">{{ unit.equipmentType }}</p>
            <p class="mt-1 text-xs text-muted">
              {{ ownerName(unit.ownerId) }}
              · {{ unit.currentLocation || 'Sin ubicación' }}
              <span v-if="unit.operatorName"> · {{ unit.operatorName }}</span>
            </p>
          </div>
          <span
            class="rounded-full px-2.5 py-0.5 text-[11px] font-semibold"
            :class="unitStatusClass(unit.status)"
          >
            {{ unit.status }}
          </span>
        </div>
      </article>
    </div>
  </div>
</template>
