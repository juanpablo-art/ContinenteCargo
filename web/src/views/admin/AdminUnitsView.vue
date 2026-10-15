<script setup lang="ts">
import { computed, ref } from 'vue';
import { Truck, Search, MapPin, UserRound } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import EmptyState from '@/components/EmptyState.vue';
import PageHeader from '@/components/PageHeader.vue';
import StatusBadge from '@/components/StatusBadge.vue';
import type { UnitStatus } from '@/lib/models';

const store = useDataStore();
const filter = ref<'all' | UnitStatus>('all');
const search = ref('');

const fleet = computed(() => store.units.filter((u) => u.notes !== 'availability_post'));

const units = computed(() => {
  let list = fleet.value;
  if (filter.value !== 'all') list = list.filter((u) => u.status === filter.value);
  const q = search.value.trim().toLowerCase();
  if (q) {
    list = list.filter(
      (u) =>
        u.plates.toLowerCase().includes(q) ||
        u.trailerNumber.toLowerCase().includes(q) ||
        u.operatorName.toLowerCase().includes(q) ||
        u.currentLocation.toLowerCase().includes(q) ||
        u.equipmentType.toLowerCase().includes(q) ||
        ownerName(u.ownerId).toLowerCase().includes(q),
    );
  }
  return list;
});

const chips = computed(() =>
  (
    [
      { id: 'all', label: 'Todas' },
      { id: 'Disponible', label: 'Disponibles' },
      { id: 'Reservada', label: 'Reservadas' },
      { id: 'En viaje', label: 'En viaje' },
    ] as { id: 'all' | UnitStatus; label: string }[]
  ).map((c) => ({
    ...c,
    n: c.id === 'all' ? fleet.value.length : fleet.value.filter((u) => u.status === c.id).length,
  })),
);

function ownerName(ownerId: string) {
  return (
    store.users.find((u) => u.uuid === ownerId || u.companyId === ownerId)?.name ??
    store.companies.find((c) => c.id === ownerId)?.name ??
    'Transportista'
  );
}
</script>

<template>
  <div class="cc-page">
    <PageHeader title="Unidades" subtitle="Flota registrada en la red de transportistas" />

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
            {{ chip.n }}
          </span>
        </button>
      </div>
      <label class="relative block md:w-80">
        <Search class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted" />
        <input
          v-model="search"
          type="search"
          class="cc-field pl-10"
          placeholder="Placas, operador, ubicación…"
        />
      </label>
    </div>

    <div v-if="!units.length" class="cc-card">
      <EmptyState
        title="Sin unidades"
        :subtitle="search || filter !== 'all' ? 'Nada coincide con el filtro.' : 'Aún no hay unidades registradas en la red.'"
      >
        <template #icon><Truck /></template>
      </EmptyState>
    </div>

    <template v-else>
      <div class="cc-card hidden overflow-hidden md:block">
        <table class="w-full text-left text-sm">
          <thead class="border-b border-line bg-background/60 text-[11.5px] font-semibold uppercase tracking-[0.06em] text-muted">
            <tr>
              <th class="px-5 py-3">Unidad</th>
              <th class="px-5 py-3">Transportista</th>
              <th class="px-5 py-3">Ubicación</th>
              <th class="px-5 py-3">Operador</th>
              <th class="px-5 py-3 text-right">Estado</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-line">
            <tr v-for="unit in units" :key="unit.id" class="transition hover:bg-background/60">
              <td class="px-5 py-3.5">
                <div class="flex items-center gap-3">
                  <span class="cc-icon-tile size-9"><Truck class="size-4" aria-hidden="true" /></span>
                  <div>
                    <p class="font-mono font-semibold text-navy">
                      {{ unit.plates || unit.trailerNumber || 'Sin placas' }}
                    </p>
                    <p class="text-xs text-muted">{{ unit.equipmentType }}</p>
                  </div>
                </div>
              </td>
              <td class="px-5 py-3.5 font-medium text-ink">{{ ownerName(unit.ownerId) }}</td>
              <td class="px-5 py-3.5 text-ink/80">{{ unit.currentLocation || '—' }}</td>
              <td class="px-5 py-3.5 text-ink/80">{{ unit.operatorName || '—' }}</td>
              <td class="px-5 py-3.5 text-right"><StatusBadge :status="unit.status" /></td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="space-y-2.5 md:hidden">
        <article v-for="unit in units" :key="unit.id" class="cc-card p-4">
          <div class="flex items-start gap-3">
            <span class="cc-icon-tile"><Truck class="size-[18px]" aria-hidden="true" /></span>
            <div class="min-w-0 flex-1">
              <p class="font-mono font-semibold text-navy">
                {{ unit.plates || unit.trailerNumber || 'Sin placas' }}
              </p>
              <p class="text-[13px] text-muted">{{ unit.equipmentType }} · {{ ownerName(unit.ownerId) }}</p>
            </div>
            <StatusBadge :status="unit.status" />
          </div>
          <div class="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-[12.5px] text-ink/75">
            <span class="inline-flex items-center gap-1.5">
              <MapPin class="size-3.5 text-muted" aria-hidden="true" />
              {{ unit.currentLocation || 'Sin ubicación' }}
            </span>
            <span v-if="unit.operatorName" class="inline-flex items-center gap-1.5">
              <UserRound class="size-3.5 text-muted" aria-hidden="true" />
              {{ unit.operatorName }}
            </span>
          </div>
        </article>
      </div>
    </template>
  </div>
</template>
