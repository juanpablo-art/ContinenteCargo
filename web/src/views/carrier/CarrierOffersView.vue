<script setup lang="ts">
import { computed, ref } from 'vue';
import StatusBadge from '@/components/StatusBadge.vue';
import EmptyState from '@/components/EmptyState.vue';
import { useDataStore } from '@/stores/data';
import { loadDestinationDisplay, loadOriginDisplay } from '@/lib/models';
import { formatDateTime, formatMoney } from '@/lib/format';
import { updateOfferFields } from '@/lib/firestore-data';

const store = useDataStore();
const editing = ref<string | null>(null);
const amount = ref(0);
const units = ref(1);

const rows = computed(() =>
  store.myOffers().map((o) => ({
    offer: o,
    load: store.loadById(o.loadId),
  })),
);

function startEdit(id: string, perUnit: number, count: number) {
  editing.value = id;
  amount.value = perUnit;
  units.value = count;
}

async function save(id: string) {
  await updateOfferFields(id, {
    proposedPrice: amount.value,
    amount: amount.value * Math.max(1, units.value),
    availableUnitCount: units.value,
  });
  editing.value = null;
}
</script>

<template>
  <div class="mx-auto w-full max-w-3xl px-4 py-6 sm:px-6">
    <h1 class="text-2xl font-bold text-navy">Mis ofertas</h1>
    <div class="mt-5 space-y-3">
      <div
        v-for="{ offer, load } in rows"
        :key="offer.id"
        class="rounded-2xl border border-line bg-card p-4"
      >
        <div class="flex justify-between gap-2">
          <div>
            <p class="text-xs text-muted">{{ load?.reference || offer.loadId.slice(0, 8) }}</p>
            <p class="text-sm font-semibold text-navy">
              <template v-if="load">
                {{ loadOriginDisplay(load) }} → {{ loadDestinationDisplay(load) }}
              </template>
              <template v-else>Carga</template>
            </p>
          </div>
          <StatusBadge :status="offer.status" />
        </div>
        <p class="mt-2 text-sm">
          {{ formatMoney(offer.amount, offer.currency) }} · {{ offer.availableUnitCount }} u.
        </p>
        <p class="text-xs text-muted">{{ formatDateTime(offer.submittedAt) }}</p>
        <div
          v-if="
            load?.status === 'Publicado' &&
            ['Activa', 'Ganando', 'Superada', 'PendienteAprobacion'].includes(offer.status)
          "
          class="mt-3"
        >
          <button
            v-if="editing !== offer.id"
            type="button"
            class="text-sm font-semibold text-blue"
            @click="
              startEdit(
                offer.id,
                offer.proposedPrice ?? offer.amount / Math.max(1, offer.availableUnitCount),
                offer.availableUnitCount,
              )
            "
          >
            Editar
          </button>
          <div v-else class="flex flex-wrap gap-2">
            <input v-model.number="amount" type="number" class="cc-field !w-28" />
            <input v-model.number="units" type="number" min="1" class="cc-field !w-20" />
            <button type="button" class="cc-btn !h-10 !w-auto px-3 text-sm" @click="save(offer.id)">
              Guardar
            </button>
          </div>
        </div>
      </div>
      <EmptyState v-if="!rows.length" title="Sin ofertas activas" />
    </div>
  </div>
</template>
