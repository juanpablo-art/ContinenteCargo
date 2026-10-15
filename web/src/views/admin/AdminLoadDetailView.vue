<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { ArrowLeft } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import {
  LOAD_STATUSES,
  loadDestinationDisplay,
  loadOriginDisplay,
  type LoadStatus,
} from '@/lib/models';
import { formatDate, formatMoney, statusBadgeClass } from '@/lib/format';

const route = useRoute();
const router = useRouter();
const store = useDataStore();

const loadId = computed(() => String(route.params.id));
const load = computed(() => store.loadById(loadId.value));
const offers = computed(() => store.offersForLoad(loadId.value));

const urgencyIncrement = ref('');
const allowCounter = ref(false);
const busy = ref(false);
const message = ref('');

const nextStatuses = computed(() =>
  LOAD_STATUSES.filter((s) => s !== 'Publicado' && s !== load.value?.status),
);

async function setStatus(status: LoadStatus) {
  if (!load.value) return;
  busy.value = true;
  try {
    await store.updateLoadStatus(load.value.id, status);
    message.value = `Estado actualizado a ${status}`;
  } finally {
    busy.value = false;
  }
}

async function cancel() {
  if (!load.value) return;
  if (!confirm('¿Cancelar esta carga?')) return;
  await store.cancelLoad(load.value.id, 'Cancelada por administrador');
}

async function closeAuction() {
  if (!load.value) return;
  await store.closeAuction(load.value.id);
  message.value = 'Subasta cerrada';
}

async function confirmLTL(offerId: string) {
  await store.confirmLTLOffer(offerId);
}

async function rejectLTL(offerId: string) {
  await store.rejectLTLOffer(offerId);
}

async function assignManual(carrierId: string) {
  if (!load.value) return;
  await store.assignManually(load.value.id, carrierId);
  message.value = 'Transportista asignado';
}

async function sendUrgency() {
  if (!load.value) return;
  const inc = Number(urgencyIncrement.value) || 0;
  await store.sendUrgencyAlert(load.value.id, inc, allowCounter.value);
  message.value = 'Alerta de urgencia enviada';
  urgencyIncrement.value = '';
}

async function approveCounter(id: string) {
  await store.approveCounterOffer(id);
}

async function rejectCounter(id: string) {
  await store.rejectCounterOffer(id);
}
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
      Carga no encontrada.
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

      <p v-if="message" class="mb-4 rounded-xl bg-success-soft px-3 py-2 text-sm text-success">
        {{ message }}
      </p>

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
            <dt class="text-muted">Límite</dt>
            <dd>{{ formatDate(load.deadline) }}</dd>
          </div>
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Modalidad</dt>
            <dd>{{ load.assignmentMode }}</dd>
          </div>
        </dl>
      </section>

      <section class="mb-4 rounded-2xl border border-line bg-card p-4">
        <h2 class="mb-3 text-sm font-semibold text-navy">Precio y mercancía</h2>
        <dl class="space-y-2 text-sm">
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Precio ofrecido</dt>
            <dd class="font-semibold text-navy">
              {{ formatMoney(load.offeredPrice, load.currency) }}
            </dd>
          </div>
          <div
            v-if="load.maxAuthorizedPriceSinIVA != null"
            class="flex justify-between gap-4"
          >
            <dt class="text-muted">Máx. autorizado (sin IVA)</dt>
            <dd>{{ formatMoney(load.maxAuthorizedPriceSinIVA, load.currency) }}</dd>
          </div>
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Equipo</dt>
            <dd>{{ load.equipmentType }}</dd>
          </div>
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Unidades</dt>
            <dd>{{ load.confirmedUnitCount }}/{{ load.unitCount }}</dd>
          </div>
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Peso</dt>
            <dd>{{ Math.round(load.weightKg).toLocaleString('es-MX') }} kg</dd>
          </div>
          <div v-if="load.merchandiseDescription">
            <dt class="text-muted">Mercancía</dt>
            <dd class="mt-1">{{ load.merchandiseDescription }}</dd>
          </div>
        </dl>
      </section>

      <section class="mb-4 rounded-2xl border border-line bg-card p-4">
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

      <!-- Offers -->
      <section v-if="offers.length" class="mb-4 rounded-2xl border border-line bg-card p-4">
        <h2 class="mb-3 text-sm font-semibold text-navy">Ofertas ({{ offers.length }})</h2>
        <div class="space-y-3">
          <div
            v-for="offer in offers"
            :key="offer.id"
            class="rounded-xl border border-line bg-background p-3"
          >
            <div class="flex flex-wrap items-start justify-between gap-2">
              <div>
                <p class="text-sm font-semibold text-navy">{{ offer.carrierName }}</p>
                <p class="text-xs text-muted">
                  {{ formatMoney(offer.proposedPrice ?? offer.amount, offer.currency) }}
                  · {{ offer.status }}
                  <span v-if="offer.availableUnitCount > 1">
                    · {{ offer.availableUnitCount }} ud.
                  </span>
                </p>
              </div>
              <div class="flex flex-wrap gap-2">
                <button
                  v-if="offer.status === 'PendienteAprobacion'"
                  type="button"
                  class="rounded-lg bg-success px-2.5 py-1 text-[11px] font-semibold text-white"
                  @click="approveCounter(offer.id)"
                >
                  Aprobar
                </button>
                <button
                  v-if="offer.status === 'PendienteAprobacion'"
                  type="button"
                  class="rounded-lg bg-danger px-2.5 py-1 text-[11px] font-semibold text-white"
                  @click="rejectCounter(offer.id)"
                >
                  Rechazar
                </button>
                <button
                  v-if="
                    load.assignmentMode === 'Consolidada LTL' &&
                    offer.status === 'Activa' &&
                    load.status === 'Publicado'
                  "
                  type="button"
                  class="rounded-lg bg-brand px-2.5 py-1 text-[11px] font-semibold text-white"
                  @click="confirmLTL(offer.id)"
                >
                  Confirmar LTL
                </button>
                <button
                  v-if="
                    load.assignmentMode === 'Confirmación Manual' &&
                    offer.status === 'Activa' &&
                    load.status === 'Publicado'
                  "
                  type="button"
                  class="rounded-lg bg-brand px-2.5 py-1 text-[11px] font-semibold text-white"
                  @click="assignManual(offer.carrierId)"
                >
                  Asignar
                </button>
                <button
                  v-if="
                    load.assignmentMode === 'Consolidada LTL' && offer.status === 'Activa'
                  "
                  type="button"
                  class="rounded-lg border border-line px-2.5 py-1 text-[11px] font-semibold text-danger"
                  @click="rejectLTL(offer.id)"
                >
                  Rechazar
                </button>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Status history -->
      <section
        v-if="load.statusHistory.length"
        class="mb-4 rounded-2xl border border-line bg-card p-4"
      >
        <h2 class="mb-3 text-sm font-semibold text-navy">Historial</h2>
        <ul class="space-y-2 text-sm">
          <li
            v-for="sc in [...load.statusHistory].reverse()"
            :key="sc.id"
            class="flex justify-between gap-3 border-b border-line pb-2 last:border-0"
          >
            <div>
              <p class="font-medium text-navy">{{ sc.status }}</p>
              <p class="text-xs text-muted">
                {{ sc.changedByName }}
                <span v-if="sc.notes"> · {{ sc.notes }}</span>
              </p>
            </div>
            <p class="shrink-0 text-xs text-muted">{{ formatDate(sc.changedAt) }}</p>
          </li>
        </ul>
      </section>

      <!-- Admin actions -->
      <section class="mb-4 rounded-2xl border border-line bg-card p-4">
        <h2 class="mb-3 text-sm font-semibold text-navy">Acciones</h2>
        <div class="mb-3 flex flex-wrap gap-2">
          <button
            v-for="st in nextStatuses"
            :key="st"
            type="button"
            class="rounded-lg border border-line bg-background px-3 py-1.5 text-xs font-medium text-navy hover:bg-blue-soft"
            :disabled="busy"
            @click="setStatus(st)"
          >
            {{ st }}
          </button>
        </div>

        <div
          v-if="load.assignmentMode === 'Subasta Inversa' && load.status === 'Publicado'"
          class="mb-3"
        >
          <button type="button" class="cc-btn h-10 text-sm" @click="closeAuction">
            Cerrar subasta
          </button>
        </div>

        <div
          v-if="load.status === 'Publicado'"
          class="mb-3 space-y-2 rounded-xl bg-background p-3"
        >
          <p class="text-xs font-semibold text-navy">Alerta de urgencia</p>
          <input
            v-model="urgencyIncrement"
            type="number"
            class="cc-field py-2 text-sm"
            placeholder="Incremento de precio (opcional)"
          />
          <label class="flex items-center gap-2 text-xs text-muted">
            <input v-model="allowCounter" type="checkbox" class="size-4" />
            Permitir contra-ofertas
          </label>
          <button type="button" class="cc-btn-secondary h-10 text-sm" @click="sendUrgency">
            Enviar alerta
          </button>
        </div>

        <button
          v-if="load.status !== 'Cancelado'"
          type="button"
          class="mt-2 w-full rounded-[10px] border border-danger/30 bg-danger-soft px-4 py-2.5 text-sm font-semibold text-danger"
          @click="cancel"
        >
          Cancelar carga
        </button>
      </section>
    </template>
  </div>
</template>
