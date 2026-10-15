<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { HandCoins, ChevronRight, Clock, Trophy, Pencil } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import EmptyState from '@/components/EmptyState.vue';
import PageHeader from '@/components/PageHeader.vue';
import SheetModal from '@/components/SheetModal.vue';
import StatusBadge from '@/components/StatusBadge.vue';
import { loadIsOpen, type OfferStatus } from '@/lib/models';
import { formatDateTime, formatMoney, timeRemaining } from '@/lib/format';
import { toast } from '@/lib/toast';

const store = useDataStore();
const selectedId = ref<string | null>(null);
const amountText = ref('');
const unitCount = ref(1);
const updated = ref(false);
const saving = ref(false);

const rows = computed(() =>
  store
    .myOffers()
    .map((offer) => ({
      offer,
      load: store.loads.find((l) => l.id === offer.loadId),
    }))
    .sort((a, b) => b.offer.submittedAt.getTime() - a.offer.submittedAt.getTime()),
);

const selected = computed(() => rows.value.find((r) => r.offer.id === selectedId.value) ?? null);

const editableStatuses: OfferStatus[] = ['Activa', 'Ganando', 'Superada'];

const isEditable = computed(() => {
  const row = selected.value;
  if (!row?.load) return false;
  return (
    editableStatuses.includes(row.offer.status) &&
    row.load.status === 'Publicado' &&
    new Date() < row.load.deadline
  );
});

const maxPositionable = computed(() => {
  const row = selected.value;
  if (!row?.load) return 1;
  const remaining = row.load.unitCount - row.load.confirmedUnitCount;
  return Math.max(1, remaining + row.offer.availableUnitCount);
});

const parsedAmount = computed(() => {
  const n = Number(amountText.value);
  return Number.isFinite(n) && n > 0 ? n : null;
});

const canUpdate = computed(() => {
  const row = selected.value;
  const amount = parsedAmount.value;
  if (!row || amount == null) return false;
  const current = row.offer.proposedPrice ?? row.offer.amount;
  return amount !== current || unitCount.value !== row.offer.availableUnitCount;
});

watch(selected, (row) => {
  updated.value = false;
  if (!row) return;
  amountText.value = String(Math.round(row.offer.proposedPrice ?? row.offer.amount));
  unitCount.value = row.offer.availableUnitCount || 1;
});

function open(id: string) {
  selectedId.value = id;
}

async function save() {
  const row = selected.value;
  const amount = parsedAmount.value;
  if (!row || amount == null || !canUpdate.value) return;
  saving.value = true;
  try {
    await store.updateOffer(row.offer.id, amount, unitCount.value);
    updated.value = true;
    toast.success('Oferta actualizada');
  } catch (e) {
    toast.error('No se pudo actualizar la oferta', e instanceof Error ? e.message : undefined);
  } finally {
    saving.value = false;
  }
}

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
      <button
        v-for="row in rows"
        :key="row.offer.id"
        type="button"
        class="cc-card-interactive group overflow-hidden text-left"
        @click="open(row.offer.id)"
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
      </button>
    </div>

    <SheetModal
      :open="Boolean(selected)"
      title="Detalle de oferta"
      :subtitle="selected?.load?.reference"
      @close="selectedId = null"
    >
      <template v-if="selected">
        <div v-if="selected.load" class="cc-card mb-4 p-4">
          <div class="flex items-center justify-between gap-3">
            <p class="text-sm font-semibold text-navy">{{ selected.load.reference }}</p>
            <StatusBadge :load="selected.load" />
          </div>
          <p class="mt-2 text-sm text-ink">
            {{ selected.load.originCity }}, {{ selected.load.originState }}
            <span class="text-muted">→</span>
            {{ selected.load.destinationCity }}, {{ selected.load.destinationState }}
          </p>
          <p class="mt-1 text-xs text-muted">
            {{ selected.load.equipmentType }} · recolección {{ formatDateTime(selected.load.pickupDate) }}
          </p>
          <p class="mt-2 text-sm">
            <span class="text-muted">Tarifa publicada </span>
            <span class="cc-money">{{ formatMoney(selected.load.offeredPrice, selected.load.currency) }}</span>
            <span v-if="selected.load.unitCount > 1" class="text-muted"> / ud</span>
          </p>
        </div>

        <div class="cc-card p-4">
          <div class="flex items-center justify-between gap-3">
            <p class="text-sm font-semibold text-navy">Tu oferta</p>
            <StatusBadge :status="selected.offer.status" />
          </div>
          <p class="cc-money mt-2 text-2xl">
            {{ formatMoney(selected.offer.proposedPrice ?? selected.offer.amount, selected.offer.currency) }}
          </p>
          <p v-if="selected.offer.availableUnitCount > 1" class="mt-1 text-xs text-muted">
            por unidad ·
            {{ formatMoney((selected.offer.proposedPrice ?? selected.offer.amount) * selected.offer.availableUnitCount, selected.offer.currency) }}
            total · {{ selected.offer.availableUnitCount }} unidades
          </p>
          <p v-if="selected.offer.notes" class="mt-2 text-xs text-muted">{{ selected.offer.notes }}</p>
          <p class="mt-2 text-[11px] text-muted">Enviada {{ formatDateTime(selected.offer.submittedAt) }}</p>
          <p v-if="updated" class="mt-3 rounded-xl bg-success-soft px-3 py-2 text-xs font-medium text-success">
            Oferta actualizada correctamente
          </p>
        </div>

        <div v-if="isEditable" class="mt-4 rounded-2xl border border-brand/20 bg-card p-4">
          <p class="flex items-center gap-2 text-sm font-semibold text-navy">
            <Pencil class="size-4 text-brand" aria-hidden="true" />
            Mejorar oferta
          </p>
          <p class="mt-1 text-xs text-muted">
            Puedes cambiar el precio o la cantidad de unidades que puedes posicionar.
          </p>
          <label class="cc-label mt-3" for="edit-amount">Precio por unidad (sin IVA)</label>
          <input id="edit-amount" v-model="amountText" type="number" min="1" class="cc-field font-semibold" />
          <p v-if="parsedAmount && unitCount > 1" class="cc-hint">
            Total: {{ formatMoney(parsedAmount * unitCount, selected.offer.currency) }}
          </p>
          <div v-if="(selected.load?.unitCount ?? 1) > 1" class="mt-3">
            <label class="cc-label" for="edit-units">Unidades a posicionar (máx. {{ maxPositionable }})</label>
            <input
              id="edit-units"
              v-model.number="unitCount"
              type="number"
              :min="1"
              :max="maxPositionable"
              class="cc-field"
            />
          </div>
          <button type="button" class="cc-btn mt-4 h-11" :disabled="!canUpdate || saving" @click="save">
            {{ saving ? 'Guardando…' : 'Actualizar oferta' }}
          </button>
        </div>

        <RouterLink
          v-if="selected.load"
          :to="{ name: 'carrier-load-detail', params: { id: selected.load.id } }"
          class="cc-btn-secondary mt-4"
          @click="selectedId = null"
        >
          Ver detalle completo de la carga
          <ChevronRight class="size-4" aria-hidden="true" />
        </RouterLink>
      </template>
    </SheetModal>
  </div>
</template>
