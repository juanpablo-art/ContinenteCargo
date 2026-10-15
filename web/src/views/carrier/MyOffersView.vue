<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { PackageSearch } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import EmptyState from '@/components/EmptyState.vue';
import { loadDestinationDisplay, loadOriginDisplay } from '@/lib/models';
import { formatDate, formatMoney, offerStatusClass } from '@/lib/format';

const store = useDataStore();
const router = useRouter();

const rows = computed(() =>
  store
    .myOffers()
    .map((offer) => ({
      offer,
      load: store.loads.find((l) => l.id === offer.loadId),
    }))
    .sort((a, b) => b.offer.submittedAt.getTime() - a.offer.submittedAt.getTime()),
);

function open(loadId: string) {
  void router.push({ name: 'carrier-load-detail', params: { id: loadId } });
}
</script>

<template>
  <div class="mx-auto max-w-5xl px-4 py-5 md:px-6">
    <h1 class="mb-1 text-xl font-bold text-navy">Mis ofertas</h1>
    <p class="mb-4 text-sm text-muted">Ofertas activas y pendientes de aprobación</p>

    <EmptyState
      v-if="!rows.length"
      title="Sin ofertas activas"
      subtitle="Las ofertas confirmadas aparecen en Mis viajes."
    >
      <template #icon><PackageSearch class="size-6" /></template>
    </EmptyState>

    <div v-else class="space-y-3">
      <button
        v-for="row in rows"
        :key="row.offer.id"
        type="button"
        class="w-full rounded-2xl border border-line bg-card p-4 text-left hover:border-blue/30"
        @click="row.load && open(row.load.id)"
      >
        <div class="flex flex-wrap items-start justify-between gap-2">
          <div class="min-w-0">
            <p class="text-sm font-semibold text-navy">
              <template v-if="row.load">
                {{ loadOriginDisplay(row.load) }} → {{ loadDestinationDisplay(row.load) }}
              </template>
              <template v-else>Carga {{ row.offer.loadId.slice(0, 8) }}…</template>
            </p>
            <p class="mt-0.5 text-xs text-muted">
              {{ row.load?.reference ?? '' }} · {{ formatDate(row.offer.submittedAt) }}
            </p>
          </div>
          <span
            class="rounded-full px-2.5 py-0.5 text-[11px] font-semibold"
            :class="offerStatusClass(row.offer.status)"
          >
            {{ row.offer.status }}
          </span>
        </div>
        <div class="mt-3 flex flex-wrap items-center justify-between gap-2 text-sm">
          <p class="font-semibold text-navy">
            {{
              formatMoney(
                row.offer.proposedPrice ?? row.offer.amount,
                row.offer.currency,
              )
            }}
            <span v-if="row.offer.isAvailabilityOnly" class="text-xs font-normal text-muted">
              (solo disponibilidad)
            </span>
          </p>
          <p v-if="row.offer.availableUnitCount > 1" class="text-xs text-muted">
            {{ row.offer.availableUnitCount }} unidades
          </p>
        </div>
      </button>
    </div>
  </div>
</template>
