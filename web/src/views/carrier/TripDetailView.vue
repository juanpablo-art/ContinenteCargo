<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
import { Check, ExternalLink, Phone, User, MapPinOff, ArrowRight } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import type { LoadStatus } from '@/lib/models';
import { formatDateTime, formatMoney } from '@/lib/format';
import { toast } from '@/lib/toast';
import PageHeader from '@/components/PageHeader.vue';
import StatusBadge from '@/components/StatusBadge.vue';
import RouteTimeline from '@/components/RouteTimeline.vue';
import EmptyState from '@/components/EmptyState.vue';
import ConfirmModal from '@/components/ConfirmModal.vue';

const route = useRoute();
const store = useDataStore();

const loadId = computed(() => String(route.params.id));
const load = computed(() => {
  const found = store.loadById(loadId.value);
  if (!found) return undefined;
  const trips = store.myTrips();
  return trips.some((t) => t.id === found.id) ? found : undefined;
});

const busy = ref(false);
const confirming = ref(false);

const carrierProgressStatuses: LoadStatus[] = [
  'Asignado',
  'En camino a recolección',
  'En origen',
  'Cargado',
  'En tránsito',
  'Entregado',
];

const currentIndex = computed(() =>
  load.value ? carrierProgressStatuses.indexOf(load.value.status) : -1,
);

const nextStatus = computed(() => {
  const idx = currentIndex.value;
  if (idx < 0 || idx >= carrierProgressStatuses.length - 1) return null;
  return carrierProgressStatuses[idx + 1];
});

const showPrivate = computed(() =>
  load.value ? store.canSeePrivateFields(load.value) : false,
);

function changeFor(status: LoadStatus) {
  return load.value?.statusHistory.find((s) => s.status === status);
}

async function advance() {
  confirming.value = false;
  if (!load.value || !nextStatus.value) return;
  busy.value = true;
  const target = nextStatus.value;
  try {
    await store.updateLoadStatus(load.value.id, target);
    toast.success('Estatus actualizado', `El viaje ahora está: ${target}`);
  } catch (e) {
    toast.error('No se pudo actualizar', e instanceof Error ? e.message : undefined);
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <div class="cc-page">
    <div v-if="!load" class="cc-card">
      <EmptyState title="Viaje no encontrado" subtitle="Este viaje no está asignado a tu cuenta.">
        <template #icon><MapPinOff /></template>
        <RouterLink :to="{ name: 'carrier-trips' }" class="cc-btn-secondary w-auto px-5">
          Ver mis viajes
        </RouterLink>
      </EmptyState>
    </div>

    <template v-else>
      <PageHeader
        :eyebrow="load.reference"
        :title="`${load.originCity} → ${load.destinationCity}`"
        :back="{ name: 'carrier-trips' }"
        back-label="Mis viajes"
      >
        <template #meta>
          <div class="mt-3 flex flex-wrap gap-2">
            <StatusBadge :status="load.status" />
            <span class="cc-badge bg-navy/[0.06] text-navy">{{ load.equipmentType }}</span>
          </div>
        </template>
      </PageHeader>

      <div class="grid gap-5 lg:grid-cols-[minmax(0,1fr)_360px] lg:items-start">
        <div class="min-w-0 space-y-4">
          <section class="cc-card p-5">
            <div class="mb-4 flex items-center justify-between">
              <h2 class="cc-h2">Progreso del viaje</h2>
              <span class="text-xs font-medium text-muted">
                {{ Math.max(currentIndex + 1, 0) }} de {{ carrierProgressStatuses.length }}
              </span>
            </div>
            <ol class="relative">
              <li
                v-for="(st, i) in carrierProgressStatuses"
                :key="st"
                class="relative flex gap-3.5 pb-5 last:pb-0"
              >
                <span
                  v-if="i < carrierProgressStatuses.length - 1"
                  class="absolute left-[13px] top-7 h-[calc(100%-1.5rem)] w-0.5 rounded-full"
                  :class="i < currentIndex ? 'bg-success' : 'bg-line'"
                  aria-hidden="true"
                />
                <span
                  class="relative z-[1] flex size-7 shrink-0 items-center justify-center rounded-full text-[12px] font-bold transition"
                  :class="
                    i < currentIndex || load.status === 'Entregado'
                      ? 'bg-success text-white'
                      : i === currentIndex
                        ? 'bg-brand text-white ring-4 ring-blue-soft'
                        : 'border-2 border-line bg-card text-muted'
                  "
                >
                  <Check v-if="i < currentIndex || load.status === 'Entregado'" class="size-4" stroke-width="3" />
                  <template v-else>{{ i + 1 }}</template>
                </span>
                <div class="min-w-0 pt-0.5">
                  <p
                    class="text-sm"
                    :class="i <= currentIndex ? 'font-semibold text-navy' : 'font-medium text-muted'"
                  >
                    {{ st }}
                  </p>
                  <p v-if="changeFor(st)" class="mt-0.5 text-xs text-muted">
                    {{ formatDateTime(changeFor(st)!.changedAt) }} · {{ changeFor(st)!.changedByName }}
                  </p>
                  <p v-else-if="i === currentIndex + 1" class="mt-0.5 text-xs text-brand">Siguiente paso</p>
                </div>
              </li>
            </ol>
            <button
              v-if="nextStatus"
              type="button"
              class="cc-btn mt-5 h-12"
              :disabled="busy"
              @click="confirming = true"
            >
              {{ busy ? 'Actualizando…' : `Marcar como “${nextStatus}”` }}
              <ArrowRight v-if="!busy" class="size-4" aria-hidden="true" />
            </button>
            <p
              v-else-if="load.status === 'Entregado'"
              class="mt-5 rounded-xl bg-success-soft px-4 py-3 text-center text-sm font-semibold text-success"
            >
              Viaje entregado. ¡Gracias!
            </p>
          </section>

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
        </div>

        <aside class="min-w-0 space-y-4 lg:sticky lg:top-24">
          <div class="cc-card overflow-hidden">
            <div class="bg-gradient-to-br from-navy to-navy-soft p-5 text-white">
              <p class="text-[12px] font-medium text-white/65">Tarifa del viaje</p>
              <p class="mt-1 text-[28px] font-bold leading-none tracking-[-0.02em] tabular-nums">
                {{ formatMoney(load.assignedPriceSinIVA ?? load.offeredPrice, load.currency) }}
              </p>
              <p class="mt-2 text-[12.5px] text-white/70">
                {{ load.includesVAT ? 'IVA incluido' : 'Más IVA' }}
              </p>
            </div>
            <a
              v-if="load.trackingUrl"
              :href="load.trackingUrl"
              target="_blank"
              rel="noopener"
              class="flex items-center justify-between px-5 py-3.5 text-sm font-semibold text-brand transition hover:bg-blue-soft/50"
            >
              Abrir rastreo
              <ExternalLink class="size-4" aria-hidden="true" />
            </a>
          </div>

          <section v-if="showPrivate" class="cc-card p-5">
            <h2 class="cc-h2 mb-3">Contacto del cliente</h2>
            <div class="space-y-2">
              <div class="flex items-center gap-3 rounded-xl bg-background p-3">
                <User class="size-4 text-muted" aria-hidden="true" />
                <span class="text-sm font-medium text-navy">{{ load.clientContactName || '—' }}</span>
              </div>
              <a
                v-if="load.clientContactPhone"
                :href="`tel:${load.clientContactPhone}`"
                class="flex items-center gap-3 rounded-xl bg-blue-soft/60 p-3 text-sm font-semibold text-brand transition hover:bg-blue-soft"
              >
                <Phone class="size-4" aria-hidden="true" />
                Llamar · {{ load.clientContactPhone }}
              </a>
            </div>
          </section>
        </aside>
      </div>
    </template>

    <ConfirmModal
      :open="confirming"
      title="¿Actualizar estatus?"
      :confirm-label="nextStatus ? `Sí, marcar “${nextStatus}”` : 'Confirmar'"
      @close="confirming = false"
      @confirm="advance"
    >
      Continente Cargo y el cliente verán el cambio de inmediato.
    </ConfirmModal>
  </div>
</template>
