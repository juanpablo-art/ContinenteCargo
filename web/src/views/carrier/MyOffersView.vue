<script setup lang="ts">
import { computed } from 'vue';
import { HandCoins, ChevronRight, Clock, Trophy } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import EmptyState from '@/components/EmptyState.vue';
import PageHeader from '@/components/PageHeader.vue';
import StatusBadge from '@/components/StatusBadge.vue';
import { loadIsOpen } from '@/lib/models';
import { formatDateTime, formatMoney, timeRemaining } from '@/lib/format';

const store = useDataStore();

const rows = computed(() =>
  store
    .myOffers()
    .map((offer) => ({
      offer,
      load: store.loads.find((l) => l.id === offer.loadId),
    }))
    .sort((a, b) => b.offer.submittedAt.getTime() - a.offer.submittedAt.getTime()),
);

const kindLabel = (mode?: string, availabilityOnly?: boolean) => {
  if (availabilityOnly) return 'Disponibilidad';
  switch (mode) {
    case 'Subasta Inversa':
      return 'Oferta en subasta';
    case 'Consolidada LTL':
      return 'Cotización LTL';
    case 'Confirmación Manual':
      return 'Disponibilidad';
    default:
      return 'Contra-oferta';
  }
};
</script>

<template>
  <div class="cc-page">
    <PageHeader title="Mis ofertas" subtitle="Ofertas activas y pendientes de aprobación" />

    <div v-if="!rows.length" class="cc-card">
      <EmptyState
        title="Sin ofertas activas"
        subtitle="Cuando ofertes en una subasta o propongas un precio, lo verás aquí. Las ofertas ganadas pasan a Mis viajes."
      >
        <template #icon><HandCoins /></template>
        <RouterLink :to="{ name: 'carrier-home' }" class="cc-btn w-auto px-5">Buscar cargas</RouterLink>
      </EmptyState>
    </div>

    <div v-else class="grid gap-3 md:grid-cols-2">
      <component
        :is="row.load ? 'router-link' : 'div'"
        v-for="row in rows"
        :key="row.offer.id"
        :to="row.load ? { name: 'carrier-load-detail', params: { id: row.load.id } } : undefined"
        class="group overflow-hidden"
        :class="row.load ? 'cc-card-interactive' : 'cc-card'"
      >
        <div class="p-4 md:p-5">
          <div class="flex items-center justify-between gap-3">
            <span class="text-[12px] font-medium text-muted">
              {{ kindLabel(row.load?.assignmentMode, row.offer.isAvailabilityOnly) }}
              <template v-if="row.load"> · {{ row.load.reference }}</template>
            </span>
            <StatusBadge :status="row.offer.status" />
          </div>
          <div class="mt-2.5 flex items-center gap-2">
            <p class="min-w-0 flex-1 truncate text-[16px] font-semibold text-navy">
              <template v-if="row.load">
                {{ row.load.originCity }}
                <span class="px-1 text-muted">→</span>
                {{ row.load.destinationCity }}
              </template>
              <template v-else>Carga {{ row.offer.loadId.slice(0, 8) }}…</template>
            </p>
            <ChevronRight
              v-if="row.load"
              class="size-5 shrink-0 text-muted transition group-hover:translate-x-0.5 group-hover:text-brand"
            />
          </div>
          <p class="mt-0.5 text-xs text-muted">Enviada {{ formatDateTime(row.offer.submittedAt) }}</p>
        </div>
        <div class="flex items-center justify-between gap-3 border-t border-line bg-background/40 px-4 py-3 md:px-5">
          <div>
            <p class="text-[11px] font-medium text-muted">Tu precio</p>
            <p class="cc-money text-[17px] leading-tight">
              {{ formatMoney(row.offer.proposedPrice ?? row.offer.amount, row.offer.currency) }}
              <span v-if="row.offer.availableUnitCount > 1" class="text-xs font-medium text-muted">
                × {{ row.offer.availableUnitCount }} u.
              </span>
            </p>
          </div>
          <span
            v-if="row.offer.status === 'Ganando'"
            class="cc-badge bg-success-soft text-success"
          >
            <Trophy class="size-3" aria-hidden="true" /> Vas ganando
          </span>
          <span
            v-else-if="row.load && loadIsOpen(row.load)"
            class="inline-flex items-center gap-1 text-[12px] font-medium text-muted"
          >
            <Clock class="size-3.5" aria-hidden="true" />
            {{ timeRemaining(row.load.deadline) }}
          </span>
        </div>
      </component>
    </div>
  </div>
</template>
