<script setup lang="ts">
import { computed, ref } from 'vue';
import { ChevronRight, MessageCircle, Phone, Search, Users } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import { phoneDigits, type AppUser, type Load } from '@/lib/models';
import { formatDateTime, initials } from '@/lib/format';
import PageHeader from '@/components/PageHeader.vue';
import EmptyState from '@/components/EmptyState.vue';
import StatusBadge from '@/components/StatusBadge.vue';
import SheetModal from '@/components/SheetModal.vue';

const store = useDataStore();
const search = ref('');
const selected = ref<AppUser | null>(null);

const carriers = computed(() => {
  const q = search.value.trim().toLowerCase();
  return store.carriersForPricer().filter((carrier) => {
    if (!q) return true;
    return (
      carrier.name.toLowerCase().includes(q) ||
      carrier.email.toLowerCase().includes(q) ||
      carrier.phone.includes(q)
    );
  });
});

function companyName(carrier: AppUser): string {
  if (!carrier.companyId) return '';
  return store.companies.find((company) => company.id === carrier.companyId)?.name ?? '';
}

function activeLoadCount(carrier: AppUser): number {
  return store.loads.filter((load) => {
    if (load.status === 'Entregado' || load.status === 'Cancelado') return false;
    return load.confirmedCarrierIds.includes(carrier.uuid) || load.assignedCarrierId === carrier.uuid;
  }).length;
}

const selectedLoads = computed(() => {
  const carrier = selected.value;
  if (!carrier) return [] as Load[];
  return store.loads
    .filter(
      (load) =>
        load.confirmedCarrierIds.includes(carrier.uuid) || load.assignedCarrierId === carrier.uuid,
    )
    .sort((a, b) => b.pickupDate.getTime() - a.pickupDate.getTime());
});

function telHref(phone: string): string {
  return `tel:${phoneDigits(phone)}`;
}

function waHref(phone: string): string {
  return `https://wa.me/${phoneDigits(phone)}`;
}
</script>

<template>
  <div class="cc-page">
    <PageHeader
      title="Mis transportistas"
      subtitle="El administrador asigna quién aparece en esta lista"
    />

    <label class="relative mb-4 block md:max-w-sm">
      <Search class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted" />
      <input v-model="search" type="search" class="cc-field pl-10" placeholder="Buscar transportista…" />
    </label>

    <div v-if="!carriers.length" class="cc-card">
      <EmptyState
        :title="search ? 'Sin resultados' : 'Sin transportistas asignados'"
        :subtitle="search ? 'Prueba con otro nombre, correo o teléfono.' : 'El administrador debe asignarte transportistas.'"
      >
        <template #icon><Users /></template>
      </EmptyState>
    </div>

    <div v-else class="space-y-2">
      <button
        v-for="carrier in carriers"
        :key="carrier.uuid"
        type="button"
        class="cc-card flex w-full items-center gap-3 p-4 text-left transition hover:border-blue/30"
        @click="selected = carrier"
      >
        <span class="flex size-10 shrink-0 items-center justify-center rounded-full bg-blue-soft text-[13px] font-bold text-brand">
          {{ initials(carrier.name) }}
        </span>
        <span class="min-w-0 flex-1">
          <span class="block truncate text-sm font-semibold text-navy">{{ carrier.name }}</span>
          <span class="mt-0.5 block truncate text-xs text-muted">
            {{ companyName(carrier) || carrier.phone }}
          </span>
        </span>
        <span v-if="activeLoadCount(carrier)" class="text-right">
          <span class="block text-base font-bold text-brand">{{ activeLoadCount(carrier) }}</span>
          <span class="block text-[10px] text-muted">cargas</span>
        </span>
        <ChevronRight class="size-4 shrink-0 text-muted" aria-hidden="true" />
      </button>
    </div>

    <SheetModal
      :open="Boolean(selected)"
      :title="selected?.name ?? ''"
      :subtitle="selected ? companyName(selected) || undefined : undefined"
      @close="selected = null"
    >
      <template v-if="selected">
        <div class="mb-4 flex flex-wrap items-center gap-2">
          <StatusBadge :status="selected.status" />
          <span class="text-sm text-muted">{{ selected.email }}</span>
          <span class="text-sm text-muted">{{ selected.phone }}</span>
        </div>
        <div class="mb-5 grid grid-cols-2 gap-2">
          <a :href="telHref(selected.phone)" class="cc-btn-secondary">
            <Phone class="size-4" aria-hidden="true" /> Llamar
          </a>
          <a :href="waHref(selected.phone)" target="_blank" rel="noopener" class="cc-btn-secondary">
            <MessageCircle class="size-4" aria-hidden="true" /> WhatsApp
          </a>
        </div>

        <h3 class="mb-2 text-sm font-semibold text-navy">Historial de cargas</h3>
        <p v-if="!selectedLoads.length" class="text-sm text-muted">
          Este transportista no tiene cargas registradas.
        </p>
        <div v-else class="space-y-2">
          <RouterLink
            v-for="load in selectedLoads"
            :key="load.id"
            :to="{ name: 'admin-load-detail', params: { id: load.id } }"
            class="block rounded-xl border border-line px-3 py-2.5 transition hover:border-blue/30"
            @click="selected = null"
          >
            <span class="flex items-center justify-between gap-2">
              <span class="text-sm font-semibold text-navy">
                {{ load.originCity }} → {{ load.destinationCity }}
              </span>
              <StatusBadge :load="load" />
            </span>
            <span class="mt-1 block text-xs text-muted">
              {{ load.reference }} · {{ formatDateTime(load.pickupDate) }}
            </span>
          </RouterLink>
        </div>
      </template>
    </SheetModal>
  </div>
</template>
