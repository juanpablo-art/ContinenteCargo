<script setup lang="ts">
import { computed, ref } from 'vue';
import { Search, SlidersHorizontal, PackageSearch, X, ShieldAlert } from '@lucide/vue';
import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';
import LoadCard from '@/components/LoadCard.vue';
import LoadCardSkeleton from '@/components/LoadCardSkeleton.vue';
import EmptyState from '@/components/EmptyState.vue';
import {
  ASSIGNMENT_MODES,
  EQUIPMENT_TYPES,
  loadIsOpen,
  type AssignmentMode,
  type EquipmentType,
} from '@/lib/models';

const auth = useAuthStore();
const store = useDataStore();
const searchText = ref('');
const filterMode = ref<AssignmentMode | null>(null);
const filterEquipment = ref<EquipmentType | null>(null);
const showEquipment = ref(false);

const openLoads = computed(() =>
  store.loadsForCurrentUser().filter((l) => l.status === 'Publicado' && loadIsOpen(l)),
);

const filteredLoads = computed(() => {
  const q = searchText.value.trim().toLowerCase();
  return openLoads.value
    .filter((load) => {
      if (filterMode.value && load.assignmentMode !== filterMode.value) return false;
      if (filterEquipment.value && load.equipmentType !== filterEquipment.value) return false;
      if (!q) return true;
      return [
        load.originCity,
        load.destinationCity,
        load.originState,
        load.destinationState,
        load.reference,
      ]
        .join(' ')
        .toLowerCase()
        .includes(q);
    })
    .sort((a, b) => a.deadline.getTime() - b.deadline.getTime());
});

const hasFilters = computed(
  () => Boolean(filterMode.value || filterEquipment.value || searchText.value.trim()),
);

const isPending = computed(() => auth.currentUser?.status === 'pending_approval');

function clearFilters() {
  filterMode.value = null;
  filterEquipment.value = null;
  searchText.value = '';
}
</script>

<template>
  <div>
    <div
      class="sticky top-[calc(3.5rem+env(safe-area-inset-top))] z-10 border-b border-line/80 bg-background/85 backdrop-blur-xl md:top-16"
    >
      <div class="mx-auto w-full max-w-6xl px-4 py-3 sm:px-6 md:px-8 md:py-4">
        <div class="mb-3 hidden items-end justify-between md:flex">
          <div>
            <h1 class="cc-h1">Cargas disponibles</h1>
            <p class="mt-1 text-sm text-muted">
              {{ openLoads.length }} cargas abiertas en tu cobertura
            </p>
          </div>
        </div>
        <div class="flex gap-2">
          <label class="relative block flex-1">
            <Search
              class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted"
              aria-hidden="true"
            />
            <input
              v-model="searchText"
              type="search"
              class="cc-field pl-10"
              placeholder="Buscar ciudad, estado o referencia"
            />
          </label>
          <button
            type="button"
            class="cc-btn-secondary w-11 shrink-0 px-0"
            :class="filterEquipment && '!border-brand !text-brand'"
            aria-label="Filtrar por equipo"
            @click="showEquipment = !showEquipment"
          >
            <SlidersHorizontal class="size-[18px]" aria-hidden="true" />
          </button>
        </div>
        <div class="cc-scroll-x mt-3">
          <button
            type="button"
            class="cc-chip"
            :class="filterMode == null && 'cc-chip-active'"
            @click="filterMode = null"
          >
            Todas
          </button>
          <button
            v-for="mode in ASSIGNMENT_MODES"
            :key="mode"
            type="button"
            class="cc-chip"
            :class="filterMode === mode && 'cc-chip-active'"
            @click="filterMode = filterMode === mode ? null : mode"
          >
            {{ mode }}
          </button>
          <button
            v-if="filterEquipment"
            type="button"
            class="cc-chip border-brand/30 bg-blue-soft text-brand"
            @click="filterEquipment = null"
          >
            {{ filterEquipment }}
            <X class="size-3.5" aria-hidden="true" />
          </button>
        </div>
        <Transition
          enter-active-class="transition duration-200 ease-out"
          enter-from-class="opacity-0 -translate-y-1"
          leave-active-class="transition duration-150"
          leave-to-class="opacity-0"
        >
          <div v-if="showEquipment" class="mt-3 flex flex-wrap gap-1.5">
            <button
              v-for="eq in EQUIPMENT_TYPES"
              :key="eq"
              type="button"
              class="cc-chip h-8 text-[12.5px]"
              :class="filterEquipment === eq && 'cc-chip-active'"
              @click="
                filterEquipment = filterEquipment === eq ? null : eq;
                showEquipment = false;
              "
            >
              {{ eq }}
            </button>
          </div>
        </Transition>
      </div>
    </div>

    <div class="mx-auto w-full max-w-6xl animate-cc-in px-4 pb-10 pt-4 sm:px-6 md:px-8 md:pt-6">
      <div
        v-if="isPending"
        class="mb-4 flex items-start gap-3 rounded-2xl border border-orange/25 bg-orange-soft/70 p-4"
      >
        <ShieldAlert class="mt-0.5 size-5 shrink-0 text-orange" aria-hidden="true" />
        <div class="text-sm">
          <p class="font-semibold text-navy">Tu cuenta está en revisión</p>
          <p class="mt-0.5 text-muted">
            Puedes ver cargas, pero podrás tomarlas u ofertar cuando un administrador te apruebe.
          </p>
        </div>
      </div>

      <p v-if="filteredLoads.length" class="mb-3 text-[13px] font-medium text-muted md:hidden">
        {{ filteredLoads.length }} {{ filteredLoads.length === 1 ? 'carga' : 'cargas' }}
        {{ hasFilters ? 'encontradas' : 'abiertas para ti' }}
      </p>

      <div v-if="!store.loadsReady" class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        <LoadCardSkeleton :count="6" />
      </div>

      <div v-else-if="!filteredLoads.length" class="cc-card">
        <EmptyState
          :title="hasFilters ? 'Nada con esos filtros' : 'Sin cargas por ahora'"
          :subtitle="
            hasFilters
              ? 'Prueba con otra ciudad o quita los filtros.'
              : 'Te avisaremos en cuanto se publique una carga en tus rutas.'
          "
        >
          <template #icon><PackageSearch /></template>
          <button v-if="hasFilters" type="button" class="cc-btn-secondary w-auto px-5" @click="clearFilters">
            Limpiar filtros
          </button>
        </EmptyState>
      </div>

      <div v-else class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        <LoadCard
          v-for="load in filteredLoads"
          :key="load.id"
          :load="load"
          :to="`/carrier/loads/${load.id}`"
        />
      </div>
    </div>
  </div>
</template>
