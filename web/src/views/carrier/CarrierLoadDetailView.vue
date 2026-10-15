<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { ArrowLeft } from '@lucide/vue';
import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';
import {
  loadDestinationDisplay,
  loadIsOpen,
  loadOriginDisplay,
} from '@/lib/models';
import { formatDate, formatMoney, statusBadgeClass } from '@/lib/format';
import TakeLoadConfirmPanel from '@/views/carrier/TakeLoadConfirmPanel.vue';
import BidOfferPanel from '@/views/carrier/BidOfferPanel.vue';
import AvailabilityPanel from '@/views/carrier/AvailabilityPanel.vue';
import LTLQuotePanel from '@/views/carrier/LTLQuotePanel.vue';

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const store = useDataStore();

const loadId = computed(() => String(route.params.id));
const load = computed(() => store.loadById(loadId.value));

const panel = ref<'none' | 'take' | 'bid' | 'avail' | 'ltl'>('none');

const isAssignedToMe = computed(() => {
  const userId = auth.currentUser?.uuid;
  if (!userId || !load.value) return false;
  return (
    load.value.confirmedCarrierIds.includes(userId) ||
    load.value.assignedCarrierId === userId
  );
});

const currentOffer = computed(() => {
  const userId = auth.currentUser?.uuid;
  if (!userId || !load.value) return null;
  return store.offersForLoad(load.value.id).find((o) => o.carrierId === userId) ?? null;
});

const showPrivate = computed(() =>
  load.value ? store.canSeePrivateFields(load.value) : false,
);

const canAct = computed(
  () => load.value && loadIsOpen(load.value) && !isAssignedToMe.value,
);
</script>

<template>
  <div class="mx-auto max-w-3xl px-4 py-5 md:px-6">
    <button
      type="button"
      class="mb-4 inline-flex items-center gap-1.5 text-sm font-medium text-brand"
      @click="router.back()"
    >
      <ArrowLeft class="size-4" />
      Volver
    </button>

    <div v-if="!load" class="rounded-2xl border border-line bg-card p-8 text-center text-muted">
      Carga no encontrada o sin acceso.
    </div>

    <template v-else>
      <div class="mb-4 flex flex-wrap items-start justify-between gap-3">
        <div>
          <p class="text-xs text-muted">{{ load.reference }}</p>
          <h1 class="text-xl font-bold text-navy">
            {{ loadOriginDisplay(load) }} → {{ loadDestinationDisplay(load) }}
          </h1>
        </div>
        <span
          class="rounded-full px-2.5 py-0.5 text-[11px] font-semibold"
          :class="statusBadgeClass(load.status)"
        >
          {{ load.status }}
        </span>
      </div>

      <section class="mb-4 rounded-2xl border border-line bg-card p-4">
        <h2 class="mb-3 text-sm font-semibold text-navy">Ruta y fechas</h2>
        <dl class="space-y-2 text-sm">
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Recolección</dt>
            <dd>{{ formatDate(load.pickupDate) }}</dd>
          </div>
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Entrega</dt>
            <dd>{{ formatDate(load.deliveryDate) }}</dd>
          </div>
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Límite para participar</dt>
            <dd>{{ formatDate(load.deadline) }}</dd>
          </div>
        </dl>
      </section>

      <section class="mb-4 rounded-2xl border border-line bg-card p-4">
        <h2 class="mb-3 text-sm font-semibold text-navy">Mercancía y equipo</h2>
        <dl class="space-y-2 text-sm">
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Equipo</dt>
            <dd>{{ load.equipmentType }}</dd>
          </div>
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Unidades</dt>
            <dd>
              <template v-if="load.confirmedUnitCount > 0 && load.confirmedUnitCount < load.unitCount">
                {{ load.unitCount - load.confirmedUnitCount }} disponibles de {{ load.unitCount }}
              </template>
              <template v-else>{{ load.unitCount }}</template>
            </dd>
          </div>
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Peso</dt>
            <dd>{{ Math.round(load.weightKg).toLocaleString('es-MX') }} kg</dd>
          </div>
          <div v-if="load.merchandiseDescription">
            <dt class="text-muted">Descripción</dt>
            <dd class="mt-1">{{ load.merchandiseDescription }}</dd>
          </div>
          <div v-if="load.specialRequirements.length">
            <dt class="text-muted">Requisitos</dt>
            <dd class="mt-1">{{ load.specialRequirements.join(', ') }}</dd>
          </div>
        </dl>
      </section>

      <section class="mb-4 rounded-2xl border border-line bg-card p-4">
        <h2 class="mb-3 text-sm font-semibold text-navy">Precio y condiciones</h2>
        <dl class="space-y-2 text-sm">
          <template v-if="load.assignmentMode === 'Consolidada LTL'">
            <p class="text-brand">Cada consolidadora cotiza su propio precio</p>
          </template>
          <template v-else>
            <div class="flex justify-between gap-4">
              <dt class="text-muted">Precio ofrecido</dt>
              <dd class="font-semibold text-navy">
                {{ formatMoney(load.offeredPrice, load.currency) }}
              </dd>
            </div>
            <div class="flex justify-between gap-4">
              <dt class="text-muted">IVA</dt>
              <dd>{{ load.includesVAT ? 'Incluido' : 'No incluido' }}</dd>
            </div>
          </template>
          <div v-if="load.includedConcepts">
            <dt class="text-muted">Incluye</dt>
            <dd class="mt-1">{{ load.includedConcepts }}</dd>
          </div>
          <div v-if="load.allowedExtraExpenses">
            <dt class="text-muted">Gastos extras</dt>
            <dd class="mt-1">{{ load.allowedExtraExpenses }}</dd>
          </div>
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Modalidad</dt>
            <dd>{{ load.assignmentMode }}</dd>
          </div>
        </dl>
      </section>

      <section
        v-if="showPrivate"
        class="mb-4 rounded-2xl border border-line bg-card p-4"
      >
        <h2 class="mb-3 text-sm font-semibold text-navy">Información operativa</h2>
        <dl class="space-y-2 text-sm">
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Contacto</dt>
            <dd>{{ load.clientContactName || '—' }}</dd>
          </div>
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Teléfono</dt>
            <dd>{{ load.clientContactPhone || '—' }}</dd>
          </div>
          <div>
            <dt class="text-muted">Dirección origen</dt>
            <dd class="mt-1">{{ load.exactPickupAddress || '—' }}</dd>
          </div>
          <div>
            <dt class="text-muted">Dirección destino</dt>
            <dd class="mt-1">{{ load.exactDeliveryAddress || '—' }}</dd>
          </div>
        </dl>
      </section>

      <section
        v-if="load.observations"
        class="mb-4 rounded-2xl border border-line bg-card p-4"
      >
        <h2 class="mb-2 text-sm font-semibold text-navy">Observaciones</h2>
        <p class="text-sm text-muted">{{ load.observations }}</p>
      </section>

      <div
        v-if="currentOffer"
        class="mb-4 rounded-2xl border border-blue/20 bg-blue-soft/60 px-4 py-3 text-sm"
      >
        Ya tienes una oferta:
        <strong>{{ currentOffer.status }}</strong>
        ·
        {{ formatMoney(currentOffer.proposedPrice ?? currentOffer.amount, currentOffer.currency) }}
      </div>

      <div
        v-if="isAssignedToMe"
        class="mb-4 rounded-2xl border border-success/20 bg-success-soft px-4 py-3 text-sm text-success"
      >
        Ya estás confirmado en este viaje.
        <RouterLink
          :to="{ name: 'carrier-trip-detail', params: { id: load.id } }"
          class="ml-1 font-semibold underline"
        >
          Ver viaje
        </RouterLink>
      </div>

      <!-- Action panels -->
      <div v-if="canAct && panel === 'none'" class="space-y-2">
        <button
          v-if="load.assignmentMode === 'Tarifa Fija'"
          type="button"
          class="cc-btn"
          @click="panel = 'take'"
        >
          Tomar carga
        </button>
        <button
          v-if="load.assignmentMode === 'Subasta Inversa'"
          type="button"
          class="cc-btn"
          @click="panel = 'bid'"
        >
          Ofertar
        </button>
        <button
          v-if="load.assignmentMode === 'Confirmación Manual'"
          type="button"
          class="cc-btn"
          @click="panel = 'avail'"
        >
          Indicar disponibilidad
        </button>
        <button
          v-if="load.assignmentMode === 'Consolidada LTL'"
          type="button"
          class="cc-btn"
          @click="panel = 'ltl'"
        >
          Enviar cotización LTL
        </button>
      </div>

      <TakeLoadConfirmPanel
        v-if="panel === 'take' && load"
        :load="load"
        @close="panel = 'none'"
        @done="panel = 'none'"
      />
      <BidOfferPanel
        v-if="panel === 'bid' && load"
        :load="load"
        @close="panel = 'none'"
        @done="panel = 'none'"
      />
      <AvailabilityPanel
        v-if="panel === 'avail' && load"
        :load="load"
        @close="panel = 'none'"
        @done="panel = 'none'"
      />
      <LTLQuotePanel
        v-if="panel === 'ltl' && load"
        :load="load"
        @close="panel = 'none'"
        @done="panel = 'none'"
      />
    </template>
  </div>
</template>
