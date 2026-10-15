<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import {
  Container,
  Layers,
  Weight,
  Ruler,
  User,
  Phone,
  Siren,
  Gavel,
  Ban,
  PackageX,
  Clock,
  HandCoins,
  Check,
  X,
  FileText,
} from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import { LOAD_STATUSES, loadIsOpen, type LoadStatus } from '@/lib/models';
import {
  deadlineTone,
  formatDateTime,
  formatMoney,
  initials,
  timeRemaining,
} from '@/lib/format';
import { toast } from '@/lib/toast';
import PageHeader from '@/components/PageHeader.vue';
import StatusBadge from '@/components/StatusBadge.vue';
import RouteTimeline from '@/components/RouteTimeline.vue';
import EmptyState from '@/components/EmptyState.vue';
import ConfirmModal from '@/components/ConfirmModal.vue';
import CartaInstruccionSheet from '@/views/admin/CartaInstruccionSheet.vue';

const route = useRoute();
const store = useDataStore();

const loadId = computed(() => String(route.params.id));
const load = computed(() => store.loadById(loadId.value));
const offers = computed(() =>
  store
    .offersForLoad(loadId.value)
    .slice()
    .sort((a, b) => (a.proposedPrice ?? a.amount) - (b.proposedPrice ?? b.amount)),
);

const urgencyIncrement = ref('');
const allowCounter = ref(false);
const busy = ref(false);
const nextStatus = ref<LoadStatus | ''>('');
const confirmCancel = ref(false);
const showCI = ref(false);
const auctionAutoClosed = ref(false);

const nextStatuses = computed(() =>
  LOAD_STATUSES.filter((s) => s !== 'Publicado' && s !== load.value?.status && s !== 'Cancelado'),
);

const fillPct = computed(() =>
  load.value ? Math.round((load.value.confirmedUnitCount / Math.max(1, load.value.unitCount)) * 100) : 0,
);

const deadlineClass = computed(() => {
  if (!load.value) return '';
  const tone = deadlineTone(load.value.deadline);
  if (tone === 'danger') return 'text-danger bg-danger-soft';
  if (tone === 'warn') return 'text-orange bg-orange-soft';
  return 'text-ink/70 bg-background';
});

async function run(action: () => Promise<unknown>, ok: string) {
  busy.value = true;
  try {
    await action();
    toast.success(ok);
  } catch (e) {
    toast.error('No se pudo completar la acción', e instanceof Error ? e.message : undefined);
  } finally {
    busy.value = false;
  }
}

function applyStatus() {
  const st = nextStatus.value;
  if (!load.value || !st) return;
  void run(() => store.updateLoadStatus(load.value!.id, st), `Estatus actualizado a ${st}`).then(
    () => (nextStatus.value = ''),
  );
}

function cancel() {
  confirmCancel.value = false;
  if (!load.value) return;
  void run(() => store.cancelLoad(load.value!.id, 'Cancelada por administrador'), 'Carga cancelada');
}

function closeAuction() {
  if (!load.value) return;
  void run(() => store.closeAuction(load.value!.id), 'Subasta cerrada');
}

watch(
  load,
  (current) => {
    if (auctionAutoClosed.value || !current) return;
    if (
      current.assignmentMode === 'Subasta Inversa' &&
      current.status === 'Publicado' &&
      new Date() > current.deadline
    ) {
      auctionAutoClosed.value = true;
      void store.closeAuction(current.id);
    }
  },
  { immediate: true },
);

function sendUrgency() {
  if (!load.value) return;
  const inc = Number(urgencyIncrement.value) || 0;
  void run(
    () => store.sendUrgencyAlert(load.value!.id, inc, allowCounter.value),
    'Alerta de urgencia enviada',
  ).then(() => (urgencyIncrement.value = ''));
}
</script>

<template>
  <div class="cc-page">
    <div v-if="!load" class="cc-card">
      <EmptyState title="Carga no encontrada" subtitle="Puede que se haya eliminado.">
        <template #icon><PackageX /></template>
        <RouterLink :to="{ name: 'admin-loads' }" class="cc-btn-secondary w-auto px-5">
          Ver cargas
        </RouterLink>
      </EmptyState>
    </div>

    <template v-else>
      <PageHeader
        :eyebrow="load.reference"
        :title="`${load.originCity} → ${load.destinationCity}`"
        :back="{ name: 'admin-loads' }"
        back-label="Cargas"
      >
        <template #meta>
          <div class="mt-3 flex flex-wrap items-center gap-2">
            <StatusBadge :load="load" />
            <span class="cc-badge bg-navy/[0.06] text-navy">{{ load.assignmentMode }}</span>
            <span v-if="loadIsOpen(load)" class="cc-badge" :class="deadlineClass">
              <Clock class="size-3" aria-hidden="true" />
              {{ timeRemaining(load.deadline) }}
            </span>
          </div>
        </template>
      </PageHeader>

      <div class="grid gap-5 lg:grid-cols-[minmax(0,1fr)_380px] lg:items-start">
        <div class="min-w-0 space-y-4">
          <section class="cc-card p-5">
            <h2 class="cc-h2 mb-4">Ruta</h2>
            <RouteTimeline
              :origin-city="load.originCity"
              :origin-state="load.originState"
              :destination-city="load.destinationCity"
              :destination-state="load.destinationState"
              :pickup-date="load.pickupDate"
              :delivery-date="load.deliveryDate"
              :pickup-address="load.exactPickupAddress"
              :delivery-address="load.exactDeliveryAddress"
            />
            <div class="mt-5 grid gap-2 border-t border-line pt-4 sm:grid-cols-2">
              <div class="flex items-center gap-3 rounded-xl bg-background p-3">
                <User class="size-4 text-muted" aria-hidden="true" />
                <div class="min-w-0">
                  <p class="text-[11px] font-medium text-muted">Contacto del cliente</p>
                  <p class="truncate text-sm font-medium text-navy">{{ load.clientContactName || '—' }}</p>
                </div>
              </div>
              <a
                :href="load.clientContactPhone ? `tel:${load.clientContactPhone}` : undefined"
                class="flex items-center gap-3 rounded-xl bg-background p-3 transition hover:bg-blue-soft/60"
              >
                <Phone class="size-4 text-muted" aria-hidden="true" />
                <div class="min-w-0">
                  <p class="text-[11px] font-medium text-muted">Teléfono</p>
                  <p class="truncate text-sm font-medium text-navy">{{ load.clientContactPhone || '—' }}</p>
                </div>
              </a>
            </div>
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
                <p class="text-sm font-semibold text-navy">{{ load.measurementsDescription || '—' }}</p>
              </div>
            </div>
            <p v-if="load.merchandiseDescription" class="mt-4 text-sm text-ink">
              {{ load.merchandiseDescription }}
            </p>
            <div v-if="load.specialRequirements.length" class="mt-3 flex flex-wrap gap-1.5">
              <span
                v-for="req in load.specialRequirements"
                :key="req"
                class="cc-badge bg-orange-soft text-orange"
              >
                {{ req }}
              </span>
            </div>
          </section>

          <section class="cc-card p-5">
            <div class="flex items-center justify-between gap-3">
              <h2 class="cc-h2 flex items-center gap-2">
                <FileText class="size-4 text-brand" aria-hidden="true" />
                Carta de instrucción
              </h2>
              <span v-if="load.cartaInstruccion" class="cc-badge bg-success-soft text-success">Generada</span>
            </div>
            <p v-if="load.confirmedUnitCount" class="mt-2 text-xs text-muted">
              {{ load.confirmedUnitCount }}/{{ load.unitCount }} unidades confirmadas
            </p>
            <p v-if="load.cartaInstruccion" class="mt-2 text-sm text-ink">
              <template v-if="load.cartaInstruccion.folio">Folio {{ load.cartaInstruccion.folio }} · </template>
              Generada {{ formatDateTime(load.cartaInstruccion.creadaAt) }}
              <template v-if="load.cartaInstruccion.archivoNombre">
                · {{ load.cartaInstruccion.archivoNombre }}
              </template>
            </p>
            <p v-else class="mt-2 text-sm text-muted">
              Aún no se ha generado la carta de instrucción para esta carga.
            </p>
            <button type="button" class="cc-btn-secondary mt-3 h-10" @click="showCI = true">
              {{ load.cartaInstruccion ? 'Ver / editar carta' : 'Generar carta de instrucción' }}
            </button>
          </section>

          <section class="cc-card overflow-hidden">
            <div class="flex items-center justify-between px-5 pb-3 pt-5">
              <h2 class="cc-h2">Ofertas</h2>
              <span class="text-xs font-medium text-muted">{{ offers.length }}</span>
            </div>
            <p v-if="!offers.length" class="px-5 pb-6 text-sm text-muted">
              Aún no hay ofertas ni confirmaciones para esta carga.
            </p>
            <ul v-else class="divide-y divide-line border-t border-line">
              <li
                v-for="(offer, i) in offers"
                :key="offer.id"
                class="flex flex-wrap items-center gap-3 px-5 py-3.5 sm:flex-nowrap"
              >
                <span
                  class="flex size-9 shrink-0 items-center justify-center rounded-full text-[12px] font-bold"
                  :class="i === 0 && load.assignmentMode === 'Subasta Inversa' ? 'bg-success-soft text-success' : 'bg-navy/[0.07] text-navy'"
                >
                  {{ initials(offer.carrierName) }}
                </span>
                <div class="min-w-0 flex-1">
                  <p class="truncate text-sm font-semibold text-navy">{{ offer.carrierName }}</p>
                  <p class="mt-0.5 truncate text-xs text-muted">
                    {{ formatDateTime(offer.submittedAt) }}
                    <template v-if="offer.availableUnitCount > 1"> · {{ offer.availableUnitCount }} unidades</template>
                    <template v-if="offer.notes"> · {{ offer.notes }}</template>
                  </p>
                </div>
                <div class="text-right">
                  <p class="cc-money text-sm">
                    {{ formatMoney(offer.proposedPrice ?? offer.amount, offer.currency) }}
                  </p>
                  <StatusBadge class="mt-1" :status="offer.status" />
                </div>
                <div class="flex w-full justify-end gap-2 sm:w-auto">
                  <template v-if="offer.status === 'PendienteAprobacion'">
                    <button
                      type="button"
                      class="cc-btn-secondary h-8 w-auto px-2.5 text-[12.5px] text-danger"
                      :disabled="busy"
                      @click="run(() => store.rejectCounterOffer(offer.id), 'Contra-oferta rechazada')"
                    >
                      <X class="size-3.5" aria-hidden="true" /> Rechazar
                    </button>
                    <button
                      type="button"
                      class="cc-btn-success h-8 w-auto px-2.5 text-[12.5px]"
                      :disabled="busy"
                      @click="run(() => store.approveCounterOffer(offer.id), 'Contra-oferta aprobada')"
                    >
                      <Check class="size-3.5" aria-hidden="true" /> Aprobar
                    </button>
                  </template>
                  <template
                    v-if="load.assignmentMode === 'Consolidada LTL' && offer.status === 'Activa' && load.status === 'Publicado'"
                  >
                    <button
                      type="button"
                      class="cc-btn-secondary h-8 w-auto px-2.5 text-[12.5px] text-danger"
                      :disabled="busy"
                      @click="run(() => store.rejectLTLOffer(offer.id), 'Cotización rechazada')"
                    >
                      Rechazar
                    </button>
                    <button
                      type="button"
                      class="cc-btn h-8 w-auto px-2.5 text-[12.5px]"
                      :disabled="busy"
                      @click="run(() => store.confirmLTLOffer(offer.id), 'Cotización LTL confirmada')"
                    >
                      Confirmar
                    </button>
                  </template>
                  <button
                    v-if="load.assignmentMode === 'Confirmación Manual' && offer.status === 'Activa' && load.status === 'Publicado'"
                    type="button"
                    class="cc-btn h-8 w-auto px-3 text-[12.5px]"
                    :disabled="busy"
                    @click="run(() => store.assignManually(load!.id, offer.carrierId), `${offer.carrierName} asignado`)"
                  >
                    Asignar
                  </button>
                </div>
              </li>
            </ul>
          </section>

          <section v-if="load.statusHistory.length" class="cc-card p-5">
            <h2 class="cc-h2 mb-4">Historial</h2>
            <ol class="relative space-y-4 border-l-2 border-line pl-5">
              <li v-for="sc in [...load.statusHistory].reverse()" :key="sc.id" class="relative">
                <span class="absolute -left-[27px] top-1 size-3 rounded-full border-2 border-card bg-brand" />
                <p class="text-sm font-semibold text-navy">{{ sc.status }}</p>
                <p class="text-xs text-muted">
                  {{ formatDateTime(sc.changedAt) }} · {{ sc.changedByName }}
                  <template v-if="sc.notes"> · {{ sc.notes }}</template>
                </p>
              </li>
            </ol>
          </section>
        </div>

        <aside class="min-w-0 space-y-4 lg:sticky lg:top-24">
          <div class="cc-card overflow-hidden">
            <div class="bg-gradient-to-br from-navy to-navy-soft p-5 text-white">
              <p class="text-[12px] font-medium text-white/65">
                Precio publicado<template v-if="load.unitCount > 1"> · por unidad</template>
              </p>
              <p class="mt-1 text-[30px] font-bold leading-none tracking-[-0.02em] tabular-nums">
                {{ formatMoney(load.offeredPrice, load.currency) }}
              </p>
              <p class="mt-2 text-[12.5px] text-white/70">{{ load.includesVAT ? 'IVA incluido' : 'Más IVA' }}</p>
            </div>
            <dl class="divide-y divide-line text-sm">
              <div v-if="load.maxAuthorizedPriceSinIVA != null" class="flex justify-between gap-3 px-5 py-3">
                <dt class="text-muted">Máx. autorizado sin IVA</dt>
                <dd class="font-semibold tabular-nums text-navy">
                  {{ formatMoney(load.maxAuthorizedPriceSinIVA, load.currency) }}
                </dd>
              </div>
              <div v-if="load.assignedPriceSinIVA != null" class="flex justify-between gap-3 px-5 py-3">
                <dt class="text-muted">Precio asignado sin IVA</dt>
                <dd class="font-semibold tabular-nums text-navy">
                  {{ formatMoney(load.assignedPriceSinIVA, load.currency) }}
                </dd>
              </div>
              <div class="px-5 py-3">
                <div class="flex justify-between gap-3">
                  <dt class="text-muted">Unidades confirmadas</dt>
                  <dd class="font-semibold tabular-nums text-navy">
                    {{ load.confirmedUnitCount }} / {{ load.unitCount }}
                  </dd>
                </div>
                <div class="mt-2 h-1.5 overflow-hidden rounded-full bg-line">
                  <div class="h-full rounded-full bg-success transition-all" :style="{ width: `${fillPct}%` }" />
                </div>
              </div>
              <div class="flex justify-between gap-3 px-5 py-3">
                <dt class="text-muted">Cierre</dt>
                <dd class="font-medium text-navy">{{ formatDateTime(load.deadline) }}</dd>
              </div>
            </dl>
          </div>

          <section class="cc-card space-y-4 p-5">
            <h2 class="cc-h2">Acciones</h2>
            <div>
              <label class="cc-label" for="next-status">Cambiar estatus</label>
              <div class="flex gap-2">
                <select id="next-status" v-model="nextStatus" class="cc-field">
                  <option value="" disabled>Seleccionar…</option>
                  <option v-for="st in nextStatuses" :key="st" :value="st">{{ st }}</option>
                </select>
                <button
                  type="button"
                  class="cc-btn w-auto shrink-0 px-4"
                  :disabled="!nextStatus || busy"
                  @click="applyStatus"
                >
                  Aplicar
                </button>
              </div>
            </div>

            <button
              v-if="load.assignmentMode === 'Subasta Inversa' && load.status === 'Publicado'"
              type="button"
              class="cc-btn-secondary"
              :disabled="busy"
              @click="closeAuction"
            >
              <Gavel class="size-4" aria-hidden="true" />
              Cerrar subasta y asignar
            </button>

            <div v-if="load.status === 'Publicado'" class="rounded-xl border border-orange/25 bg-orange-soft/50 p-3.5">
              <p class="flex items-center gap-2 text-[13px] font-semibold text-navy">
                <Siren class="size-4 text-orange" aria-hidden="true" /> Alerta de urgencia
              </p>
              <p class="mt-0.5 text-xs text-muted">Reenvía la carga a transportistas con un incentivo.</p>
              <div class="relative mt-3">
                <span class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm font-medium text-muted">
                  + $
                </span>
                <input
                  v-model="urgencyIncrement"
                  type="number"
                  inputmode="numeric"
                  class="cc-field pl-10"
                  placeholder="Incremento (opcional)"
                />
              </div>
              <label class="mt-2 flex items-center gap-2 text-[13px] text-ink/80">
                <input v-model="allowCounter" type="checkbox" class="size-4" />
                Permitir contra-ofertas
              </label>
              <p
                v-if="allowCounter && load.assignmentMode === 'Tarifa Fija'"
                class="mt-2 text-xs text-muted"
              >
                La modalidad cambiará de Tarifa Fija a Subasta Inversa.
              </p>
              <button type="button" class="cc-btn mt-3 h-10 bg-orange shadow-none hover:bg-orange/90" :disabled="busy" @click="sendUrgency">
                <HandCoins class="size-4" aria-hidden="true" /> Enviar alerta
              </button>
            </div>

            <button
              v-if="load.status !== 'Cancelado' && load.status !== 'Entregado'"
              type="button"
              class="cc-btn-ghost w-full text-danger hover:bg-danger-soft"
              @click="confirmCancel = true"
            >
              <Ban class="size-4" aria-hidden="true" /> Cancelar carga
            </button>
          </section>
        </aside>
      </div>
    </template>

    <CartaInstruccionSheet v-if="load" :open="showCI" :load="load" @close="showCI = false" />

    <ConfirmModal
      :open="confirmCancel"
      title="¿Cancelar esta carga?"
      confirm-label="Sí, cancelar carga"
      danger
      @close="confirmCancel = false"
      @confirm="cancel"
    >
      Se notificará a los transportistas confirmados y la carga dejará de estar visible.
    </ConfirmModal>
  </div>
</template>
