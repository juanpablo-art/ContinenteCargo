<script setup lang="ts">
import { computed, nextTick, ref } from 'vue';
import { useRoute } from 'vue-router';
import {
  Clock,
  Container,
  Layers,
  Weight,
  Ruler,
  Lock,
  Phone,
  User,
  CircleCheck,
  HandCoins,
  PackageX,
  ChevronRight,
} from '@lucide/vue';
import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';
import { loadIsOpen } from '@/lib/models';
import { deadlineTone, formatDateTime, formatMoney, statusLabel, timeRemaining } from '@/lib/format';
import PageHeader from '@/components/PageHeader.vue';
import StatusBadge from '@/components/StatusBadge.vue';
import RouteTimeline from '@/components/RouteTimeline.vue';
import EmptyState from '@/components/EmptyState.vue';
import TakeLoadConfirmPanel from '@/views/carrier/TakeLoadConfirmPanel.vue';
import BidOfferPanel from '@/views/carrier/BidOfferPanel.vue';
import AvailabilityPanel from '@/views/carrier/AvailabilityPanel.vue';
import LTLQuotePanel from '@/views/carrier/LTLQuotePanel.vue';

const route = useRoute();
const auth = useAuthStore();
const store = useDataStore();

const loadId = computed(() => String(route.params.id));
const load = computed(() => store.loadById(loadId.value));

type Panel = 'none' | 'take' | 'bid' | 'avail' | 'ltl';
const panel = ref<Panel>('none');
const actionsEl = ref<HTMLElement | null>(null);

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
  () => Boolean(load.value && loadIsOpen(load.value) && !isAssignedToMe.value),
);

const primaryAction = computed<{ panel: Panel; label: string } | null>(() => {
  switch (load.value?.assignmentMode) {
    case 'Tarifa Fija':
      return { panel: 'take', label: 'Tomar carga' };
    case 'Subasta Inversa':
      return { panel: 'bid', label: 'Ofertar' };
    case 'Confirmación Manual':
      return { panel: 'avail', label: 'Indicar disponibilidad' };
    case 'Consolidada LTL':
      return { panel: 'ltl', label: 'Enviar cotización LTL' };
    default:
      return null;
  }
});

const remainingUnits = computed(() =>
  load.value ? load.value.unitCount - load.value.confirmedUnitCount : 0,
);

const deadlineClass = computed(() => {
  if (!load.value) return '';
  const tone = deadlineTone(load.value.deadline);
  if (tone === 'danger') return 'text-danger bg-danger-soft';
  if (tone === 'warn') return 'text-orange bg-orange-soft';
  return 'text-ink/70 bg-background';
});

async function openPanel(p: Panel) {
  panel.value = p;
  await nextTick();
  actionsEl.value?.scrollIntoView({ behavior: 'smooth', block: 'start' });
}
</script>

<template>
  <div class="cc-page">
    <div v-if="!load" class="cc-card">
      <EmptyState
        title="Carga no disponible"
        subtitle="La carga no existe, ya se asignó o no está en tu cobertura."
      >
        <template #icon><PackageX /></template>
        <RouterLink :to="{ name: 'carrier-home' }" class="cc-btn-secondary w-auto px-5">
          Ver cargas disponibles
        </RouterLink>
      </EmptyState>
    </div>

    <template v-else>
      <PageHeader
        :eyebrow="load.reference"
        :title="`${load.originCity} → ${load.destinationCity}`"
        back
        back-label="Cargas"
      >
        <template #meta>
          <div class="mt-3 flex flex-wrap items-center gap-2">
            <StatusBadge :load="load" />
            <span class="cc-badge bg-navy/[0.06] text-navy">{{ load.assignmentMode }}</span>
            <span
              v-if="loadIsOpen(load)"
              class="cc-badge"
              :class="deadlineClass"
            >
              <Clock class="size-3" aria-hidden="true" />
              {{ timeRemaining(load.deadline) }}
            </span>
          </div>
        </template>
      </PageHeader>

      <div class="grid gap-5 lg:grid-cols-[minmax(0,1fr)_380px] lg:items-start">
        <!-- Summary + actions (first on mobile, right column on desktop) -->
        <aside ref="actionsEl" class="scroll-mt-24 space-y-4 lg:sticky lg:top-24 lg:col-start-2 lg:row-start-1">
          <div class="cc-card overflow-hidden">
            <div class="bg-gradient-to-br from-navy to-navy-soft p-5 text-white">
              <p class="text-[12px] font-medium text-white/65">
                {{ load.assignmentMode === 'Subasta Inversa' ? 'Precio de referencia' : 'Tarifa ofrecida' }}
                <template v-if="load.unitCount > 1">· por unidad</template>
              </p>
              <p
                v-if="load.assignmentMode === 'Consolidada LTL'"
                class="mt-1 text-xl font-bold"
              >
                Cotiza tu precio
              </p>
              <p v-else class="mt-1 text-[30px] font-bold leading-none tracking-[-0.02em] tabular-nums">
                {{ formatMoney(load.offeredPrice, load.currency) }}
              </p>
              <p class="mt-2 text-[12.5px] text-white/70">
                {{ load.includesVAT ? 'IVA incluido' : 'Más IVA' }}
                <template v-if="load.assignmentMode === 'Subasta Inversa'">
                  · Decremento mín. {{ formatMoney(load.minBidDecrement, load.currency) }}
                </template>
              </p>
            </div>
            <dl class="grid grid-cols-2 divide-x divide-line border-b border-line text-center">
              <div class="px-3 py-3">
                <dt class="text-[11px] font-medium text-muted">Unidades</dt>
                <dd class="mt-0.5 text-sm font-semibold text-navy">
                  <template v-if="load.confirmedUnitCount > 0 && remainingUnits > 0">
                    {{ remainingUnits }} de {{ load.unitCount }} libres
                  </template>
                  <template v-else>{{ load.unitCount }}</template>
                </dd>
              </div>
              <div class="px-3 py-3">
                <dt class="text-[11px] font-medium text-muted">Cierra</dt>
                <dd class="mt-0.5 text-sm font-semibold text-navy">
                  {{ formatDateTime(load.deadline) }}
                </dd>
              </div>
            </dl>

            <div class="space-y-3 p-4">
              <div
                v-if="isAssignedToMe"
                class="flex items-start gap-3 rounded-xl bg-success-soft p-3 text-sm"
              >
                <CircleCheck class="mt-0.5 size-5 shrink-0 text-success" aria-hidden="true" />
                <div>
                  <p class="font-semibold text-success">Estás confirmado en este viaje</p>
                  <RouterLink
                    :to="{ name: 'carrier-trip-detail', params: { id: load.id } }"
                    class="mt-1 inline-flex items-center gap-0.5 font-semibold text-navy hover:text-brand"
                  >
                    Ver viaje <ChevronRight class="size-4" aria-hidden="true" />
                  </RouterLink>
                </div>
              </div>

              <div
                v-else-if="currentOffer"
                class="flex items-start gap-3 rounded-xl bg-blue-soft/70 p-3 text-sm"
              >
                <HandCoins class="mt-0.5 size-5 shrink-0 text-brand" aria-hidden="true" />
                <div>
                  <p class="font-semibold text-navy">
                    Tu oferta: {{ statusLabel(currentOffer.status) }}
                  </p>
                  <p class="mt-0.5 text-muted">
                    {{ formatMoney(currentOffer.proposedPrice ?? currentOffer.amount, currentOffer.currency) }}
                    · enviada {{ formatDateTime(currentOffer.submittedAt) }}
                  </p>
                </div>
              </div>

              <button
                v-if="canAct && panel === 'none' && primaryAction"
                type="button"
                class="cc-btn h-12"
                @click="openPanel(primaryAction.panel)"
              >
                {{ primaryAction.label }}
              </button>
              <p
                v-else-if="!canAct && !isAssignedToMe"
                class="text-center text-[13px] text-muted"
              >
                Esta carga ya no recibe participaciones.
              </p>
            </div>
          </div>

          <TakeLoadConfirmPanel
            v-if="panel === 'take'"
            :load="load"
            @close="panel = 'none'"
            @done="panel = 'none'"
          />
          <BidOfferPanel
            v-if="panel === 'bid'"
            :load="load"
            @close="panel = 'none'"
            @done="panel = 'none'"
          />
          <AvailabilityPanel
            v-if="panel === 'avail'"
            :load="load"
            @close="panel = 'none'"
            @done="panel = 'none'"
          />
          <LTLQuotePanel
            v-if="panel === 'ltl'"
            :load="load"
            @close="panel = 'none'"
            @done="panel = 'none'"
          />
        </aside>

        <!-- Details -->
        <div class="min-w-0 space-y-4 lg:col-start-1 lg:row-start-1">
          <section class="cc-card p-5">
            <h2 class="cc-h2 mb-4">Ruta</h2>
            <RouteTimeline
              :origin-city="load.originCity"
              :origin-state="load.originState"
              :destination-city="load.destinationCity"
              :destination-state="load.destinationState"
              :pickup-date="load.pickupDate"
              :delivery-date="load.deliveryDate"
              :pickup-address="showPrivate ? load.exactPickupAddress : undefined"
              :delivery-address="showPrivate ? load.exactDeliveryAddress : undefined"
            />
          </section>

          <section class="cc-card p-5">
            <h2 class="cc-h2 mb-4">Mercancía y equipo</h2>
            <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
              <div class="rounded-xl bg-background p-3">
                <Container class="size-4 text-muted" aria-hidden="true" />
                <p class="mt-2 text-[11px] font-medium text-muted">Equipo</p>
                <p class="text-sm font-semibold text-navy">{{ load.equipmentType }}</p>
              </div>
              <div class="rounded-xl bg-background p-3">
                <Layers class="size-4 text-muted" aria-hidden="true" />
                <p class="mt-2 text-[11px] font-medium text-muted">Unidades</p>
                <p class="text-sm font-semibold text-navy">{{ load.unitCount }}</p>
              </div>
              <div class="rounded-xl bg-background p-3">
                <Weight class="size-4 text-muted" aria-hidden="true" />
                <p class="mt-2 text-[11px] font-medium text-muted">Peso</p>
                <p class="text-sm font-semibold text-navy">
                  {{ Math.round(load.weightKg).toLocaleString('es-MX') }} kg
                </p>
              </div>
              <div class="rounded-xl bg-background p-3">
                <Ruler class="size-4 text-muted" aria-hidden="true" />
                <p class="mt-2 text-[11px] font-medium text-muted">Medidas</p>
                <p class="text-sm font-semibold text-navy">
                  {{ load.measurementsDescription || '—' }}
                </p>
              </div>
            </div>
            <div v-if="load.merchandiseDescription" class="mt-4">
              <p class="text-[13px] font-medium text-muted">Descripción</p>
              <p class="mt-1 text-sm text-ink">{{ load.merchandiseDescription }}</p>
            </div>
            <div v-if="load.specialRequirements.length" class="mt-4">
              <p class="text-[13px] font-medium text-muted">Requisitos especiales</p>
              <div class="mt-2 flex flex-wrap gap-1.5">
                <span
                  v-for="req in load.specialRequirements"
                  :key="req"
                  class="cc-badge bg-orange-soft text-orange"
                >
                  {{ req }}
                </span>
              </div>
            </div>
          </section>

          <section
            v-if="load.includedConcepts || load.allowedExtraExpenses || load.observations"
            class="cc-card p-5"
          >
            <h2 class="cc-h2 mb-2">Condiciones</h2>
            <dl>
              <div v-if="load.includedConcepts" class="border-b border-line/70 py-3 last:border-0">
                <dt class="text-[13px] font-medium text-muted">Incluye</dt>
                <dd class="mt-1 text-sm text-ink">{{ load.includedConcepts }}</dd>
              </div>
              <div v-if="load.allowedExtraExpenses" class="border-b border-line/70 py-3 last:border-0">
                <dt class="text-[13px] font-medium text-muted">Gastos extra permitidos</dt>
                <dd class="mt-1 text-sm text-ink">{{ load.allowedExtraExpenses }}</dd>
              </div>
              <div v-if="load.observations" class="py-3">
                <dt class="text-[13px] font-medium text-muted">Observaciones</dt>
                <dd class="mt-1 text-sm text-ink">{{ load.observations }}</dd>
              </div>
            </dl>
          </section>

          <section v-if="showPrivate" class="cc-card p-5">
            <h2 class="cc-h2 mb-3">Contacto del cliente</h2>
            <div class="grid gap-3 sm:grid-cols-2">
              <div class="flex items-center gap-3 rounded-xl bg-background p-3">
                <User class="size-4 text-muted" aria-hidden="true" />
                <span class="text-sm font-medium text-navy">{{ load.clientContactName || '—' }}</span>
              </div>
              <a
                :href="load.clientContactPhone ? `tel:${load.clientContactPhone}` : undefined"
                class="flex items-center gap-3 rounded-xl bg-background p-3 transition hover:bg-blue-soft/60"
              >
                <Phone class="size-4 text-muted" aria-hidden="true" />
                <span class="text-sm font-medium text-navy">{{ load.clientContactPhone || '—' }}</span>
              </a>
            </div>
          </section>
          <div
            v-else
            class="flex items-center gap-3 rounded-2xl border border-dashed border-line px-4 py-3.5 text-[13px] text-muted"
          >
            <Lock class="size-4 shrink-0" aria-hidden="true" />
            Las direcciones exactas y el contacto del cliente se muestran al confirmar tu participación.
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
