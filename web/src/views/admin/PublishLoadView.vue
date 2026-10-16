<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import {
  ArrowDown,
  BadgeDollarSign,
  Gavel,
  Hand,
  Boxes,
  Smartphone,
  Mail,
  MessageCircle,
  PhoneCall,
  Lock,
  Plus,
} from '@lucide/vue';
import type { Component } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';
import {
  ASSIGNMENT_MODES,
  EQUIPMENT_TYPES,
  MEXICAN_STATES,
  SPECIAL_REQUIREMENTS,
  US_STATES,
  newUuid,
  type AssignmentMode,
  type Currency,
  type EquipmentType,
  type Load,
  type SpecialRequirement,
} from '@/lib/models';
import { toDatetimeLocalValue, fromDatetimeLocalValue, formatMoney } from '@/lib/format';
import PageHeader from '@/components/PageHeader.vue';
import ResultState from '@/components/ResultState.vue';

const auth = useAuthStore();
const store = useDataStore();

const published = ref(false);
const publishedId = ref('');
const publishedSummary = ref({ reference: '', route: '', price: '', equipment: '' });

const reference = ref('');
const originCity = ref('');
const originCountry = ref<'mx' | 'us'>('mx');
const originMXState = ref<string>('N.L.');
const originUSState = ref<string>('TX');
const destinationCity = ref('');
const destinationCountry = ref<'mx' | 'us'>('mx');
const destinationMXState = ref<string>('CDMX');
const destinationUSState = ref<string>('CA');

const now = Date.now();
const pickupDate = ref(toDatetimeLocalValue(new Date(now + 86400_000)));
const deliveryDate = ref(toDatetimeLocalValue(new Date(now + 172800_000)));
const deadline = ref(toDatetimeLocalValue(new Date(now + 43200_000)));

const equipmentType = ref<EquipmentType>("Caja Seca 53'");
const unitCount = ref(1);
const weightText = ref('');
const merchandiseDesc = ref('');
const measurementsDesc = ref('');
const selectedRequirements = ref<SpecialRequirement[]>([]);
const priceText = ref('');
const maxPriceText = ref('');
const currency = ref<Currency>('MXN');
const includesVAT = ref(false);
const includedConcepts = ref('');
const allowedExtras = ref('');
const assignmentMode = ref<AssignmentMode>('Tarifa Fija');
const minDecrementText = ref('500');
const observations = ref('');
const clientContact = ref('');
const clientPhone = ref('');
const pickupAddress = ref('');
const deliveryAddress = ref('');
const notifyInApp = ref(true);
const notifyEmail = ref(true);
const notifyWhatsApp = ref(true);
const notifyAICall = ref(false);
const saving = ref(false);
const error = ref('');

const isLTL = computed(() => assignmentMode.value === 'Consolidada LTL');

const originState = computed(() =>
  originCountry.value === 'mx' ? originMXState.value : originUSState.value,
);
const destinationState = computed(() =>
  destinationCountry.value === 'mx' ? destinationMXState.value : destinationUSState.value,
);

const isValid = computed(() => {
  if (!originCity.value.trim() || !destinationCity.value.trim()) return false;
  if (isLTL.value) return Boolean(weightText.value && measurementsDesc.value);
  return Boolean(priceText.value);
});

const modeMeta: Record<AssignmentMode, { icon: Component; hint: string }> = {
  'Tarifa Fija': { icon: BadgeDollarSign, hint: 'El primero en confirmar se queda la carga' },
  'Subasta Inversa': { icon: Gavel, hint: 'Gana la oferta más baja al cierre' },
  'Confirmación Manual': { icon: Hand, hint: 'Tú eliges entre los disponibles' },
  'Consolidada LTL': { icon: Boxes, hint: 'Consolidadoras envían cotización' },
};

const channels = computed(() => [
  { model: notifyInApp, label: 'En app', icon: Smartphone },
  { model: notifyEmail, label: 'Correo', icon: Mail },
  { model: notifyWhatsApp, label: 'WhatsApp', icon: MessageCircle },
  { model: notifyAICall, label: 'Llamada IA', icon: PhoneCall },
]);

const summary = computed(() => {
  const o = originCity.value.trim() || 'Origen';
  const d = destinationCity.value.trim() || 'Destino';
  const price = !isLTL.value && priceText.value ? formatMoney(Number(priceText.value), currency.value) : null;
  return { route: `${o} → ${d}`, price };
});

const missingFields = computed(() => {
  const items: string[] = [];
  if (!originCity.value.trim()) items.push('origen');
  if (!destinationCity.value.trim()) items.push('destino');
  if (isLTL.value) {
    if (!weightText.value) items.push('peso');
    if (!measurementsDesc.value.trim()) items.push('medidas');
  } else if (!priceText.value) {
    items.push('precio');
  }
  return items;
});

const isDesktopBar = ref(false);
const keyboardInset = ref(0);

function syncPublishBar() {
  isDesktopBar.value = window.matchMedia('(min-width: 768px)').matches;
  const viewport = window.visualViewport;
  const active = document.activeElement;
  const editing =
    active instanceof HTMLInputElement ||
    active instanceof HTMLTextAreaElement ||
    active instanceof HTMLSelectElement;
  if (!viewport || isDesktopBar.value || !editing) {
    keyboardInset.value = 0;
    return;
  }
  const covered = window.innerHeight - viewport.height - viewport.offsetTop;
  keyboardInset.value = covered > 120 ? covered : 0;
}

const publishBarStyle = computed(() => {
  if (isDesktopBar.value) return { left: '248px', right: '0px', bottom: '0px' };
  if (keyboardInset.value > 0) {
    return { left: '0px', right: '0px', bottom: `${keyboardInset.value}px` };
  }
  return {
    left: '0px',
    right: '0px',
    bottom: 'calc(4.5rem + env(safe-area-inset-bottom))',
  };
});

onMounted(() => {
  syncPublishBar();
  window.addEventListener('resize', syncPublishBar);
  window.addEventListener('focusin', syncPublishBar);
  window.addEventListener('focusout', syncPublishBar);
  window.visualViewport?.addEventListener('resize', syncPublishBar);
  window.visualViewport?.addEventListener('scroll', syncPublishBar);
});

onUnmounted(() => {
  window.removeEventListener('resize', syncPublishBar);
  window.removeEventListener('focusin', syncPublishBar);
  window.removeEventListener('focusout', syncPublishBar);
  window.visualViewport?.removeEventListener('resize', syncPublishBar);
  window.visualViewport?.removeEventListener('scroll', syncPublishBar);
});

function toggleReq(req: SpecialRequirement) {
  const i = selectedRequirements.value.indexOf(req);
  if (i >= 0) selectedRequirements.value.splice(i, 1);
  else selectedRequirements.value.push(req);
}

async function publish() {
  if (!isValid.value || !auth.currentUser || saving.value) return;
  const pickup = fromDatetimeLocalValue(pickupDate.value);
  const delivery = fromDatetimeLocalValue(deliveryDate.value);
  const closeAt = fromDatetimeLocalValue(deadline.value);
  if ([pickup, delivery, closeAt].some((date) => Number.isNaN(date.getTime()))) {
    error.value = 'Revisa las fechas de recolección, entrega y cierre.';
    return;
  }
  saving.value = true;
  error.value = '';
  try {
    const price = Number(priceText.value) || 0;
    const maxPrice = maxPriceText.value ? Number(maxPriceText.value) : undefined;
    const refCode =
      reference.value.trim() ||
      `CC-${new Date().toISOString().slice(0, 10).replace(/-/g, '')}-${Math.floor(Math.random() * 900 + 100)}`;

    const load: Load = {
      id: newUuid(),
      reference: refCode,
      originCity: originCity.value.trim(),
      originState: originState.value,
      destinationCity: destinationCity.value.trim(),
      destinationState: destinationState.value,
      pickupDate: pickup,
      deliveryDate: delivery,
      equipmentType: equipmentType.value,
      unitCount: Math.max(1, Number(unitCount.value) || 1),
      weightKg: Number(weightText.value) || 0,
      merchandiseDescription: merchandiseDesc.value.trim(),
      measurementsDescription: measurementsDesc.value.trim(),
      specialRequirements: [...selectedRequirements.value],
      offeredPrice: price,
      currency: currency.value,
      includesVAT: includesVAT.value,
      maxAuthorizedPriceSinIVA: maxPrice,
      includedConcepts: includedConcepts.value.trim(),
      allowedExtraExpenses: allowedExtras.value.trim(),
      assignmentMode: assignmentMode.value,
      deadline: closeAt,
      minBidDecrement: Number(minDecrementText.value) || 100,
      observations: observations.value.trim(),
      status: 'Publicado',
      publishedBy: auth.currentUser.uuid,
      publishedAt: new Date(),
      trackingUrl: '',
      statusHistory: [],
      clientContactName: clientContact.value.trim(),
      clientContactPhone: clientPhone.value.trim(),
      exactPickupAddress: pickupAddress.value.trim(),
      exactDeliveryAddress: deliveryAddress.value.trim(),
      notificationChannels: {
        inApp: notifyInApp.value,
        email: notifyEmail.value,
        whatsapp: notifyWhatsApp.value,
        aiCall: notifyAICall.value,
      },
      confirmedCarrierIds: [],
      confirmedUnitCount: 0,
    };

    await store.publishLoad(load);
    publishedId.value = load.id;
    publishedSummary.value = {
      reference: load.reference,
      route: `${load.originCity}, ${load.originState} → ${load.destinationCity}, ${load.destinationState}`,
      price: formatMoney(load.offeredPrice, load.currency),
      equipment: load.equipmentType,
    };
    published.value = true;
    window.scrollTo({ top: 0, behavior: 'smooth' });
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'No se pudo publicar la carga';
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <div class="cc-page-narrow">
    <template v-if="published">
      <div class="cc-card mx-auto mt-6 max-w-md p-6">
        <ResultState
          ok
          title="¡Carga publicada!"
          :body="`${publishedSummary.reference} · ${publishedSummary.route}`"
          action-label="Ver detalle de la carga"
          @action="$router.push({ name: 'admin-load-detail', params: { id: publishedId } })"
        />
        <p class="-mt-1 text-center text-sm text-muted">
          {{ publishedSummary.equipment }} · {{ publishedSummary.price }}
        </p>
        <p class="mt-1 text-center text-[13px] text-muted">
          Los transportistas con cobertura ya recibieron el aviso.
        </p>
        <button type="button" class="cc-btn-ghost mx-auto mt-3 flex" @click="published = false">
          <Plus class="size-4" aria-hidden="true" /> Publicar otra carga
        </button>
      </div>
    </template>

    <template v-else>
      <PageHeader
        title="Publicar carga"
        subtitle="Se notificará al instante a los transportistas con cobertura"
        :back="{ name: 'admin-loads' }"
        back-label="Cargas"
      />

      <p v-if="error" class="mb-4 rounded-xl bg-danger-soft px-4 py-3 text-sm text-danger">
        {{ error }}
      </p>

      <form id="publish-form" class="space-y-4 pb-36 md:pb-28" @submit.prevent="publish">
        <!-- 1. Modality -->
        <section class="cc-card p-5">
          <h2 class="cc-h2 mb-1 flex items-center gap-2.5">
            <span class="flex size-6 items-center justify-center rounded-full bg-navy text-[11px] font-bold text-white">1</span>
            Modalidad de asignación
          </h2>
          <div class="mt-4 grid gap-2 sm:grid-cols-2">
            <label
              v-for="m in ASSIGNMENT_MODES"
              :key="m"
              class="flex cursor-pointer items-start gap-3 rounded-xl border p-3.5 transition"
              :class="
                assignmentMode === m
                  ? 'border-brand bg-blue-soft/60 ring-1 ring-brand'
                  : 'border-line hover:border-blue/30'
              "
            >
              <input v-model="assignmentMode" type="radio" :value="m" class="sr-only" />
              <span
                class="cc-icon-tile size-9"
                :class="assignmentMode === m ? 'bg-brand text-white' : ''"
              >
                <component :is="modeMeta[m].icon" class="size-[18px]" aria-hidden="true" />
              </span>
              <span class="min-w-0">
                <span class="block text-sm font-semibold text-navy">{{ m }}</span>
                <span class="mt-0.5 block text-xs leading-snug text-muted">{{ modeMeta[m].hint }}</span>
              </span>
            </label>
          </div>
        </section>

        <!-- 2. Route -->
        <section class="cc-card p-5">
          <h2 class="cc-h2 mb-4 flex items-center gap-2.5">
            <span class="flex size-6 items-center justify-center rounded-full bg-navy text-[11px] font-bold text-white">2</span>
            Ruta y fechas
          </h2>

          <div class="rounded-2xl border border-line p-4">
            <p class="cc-label flex items-center gap-2">
              <span class="size-2.5 rounded-full border-2 border-brand" /> Origen
            </p>
            <div class="grid gap-3 sm:grid-cols-[1fr_120px_1fr]">
              <input v-model="originCity" class="cc-field" placeholder="Ciudad *" required aria-label="Ciudad origen" />
              <select v-model="originCountry" class="cc-field" aria-label="País origen">
                <option value="mx">México</option>
                <option value="us">EE.UU.</option>
              </select>
              <select v-if="originCountry === 'mx'" v-model="originMXState" class="cc-field" aria-label="Estado origen">
                <option v-for="s in MEXICAN_STATES" :key="s" :value="s">{{ s }}</option>
              </select>
              <select v-else v-model="originUSState" class="cc-field" aria-label="Estado origen">
                <option v-for="s in US_STATES" :key="s" :value="s">{{ s }}</option>
              </select>
            </div>
            <div class="flex justify-center py-2 text-muted" aria-hidden="true">
              <ArrowDown class="size-4" />
            </div>
            <p class="cc-label flex items-center gap-2">
              <span class="size-2.5 rounded-full bg-orange" /> Destino
            </p>
            <div class="grid gap-3 sm:grid-cols-[1fr_120px_1fr]">
              <input v-model="destinationCity" class="cc-field" placeholder="Ciudad *" required aria-label="Ciudad destino" />
              <select v-model="destinationCountry" class="cc-field" aria-label="País destino">
                <option value="mx">México</option>
                <option value="us">EE.UU.</option>
              </select>
              <select v-if="destinationCountry === 'mx'" v-model="destinationMXState" class="cc-field" aria-label="Estado destino">
                <option v-for="s in MEXICAN_STATES" :key="s" :value="s">{{ s }}</option>
              </select>
              <select v-else v-model="destinationUSState" class="cc-field" aria-label="Estado destino">
                <option v-for="s in US_STATES" :key="s" :value="s">{{ s }}</option>
              </select>
            </div>
          </div>

          <div class="mt-4 grid gap-4 sm:grid-cols-3">
            <div>
              <label class="cc-label" for="p-pick">Recolección</label>
              <input id="p-pick" v-model="pickupDate" type="datetime-local" class="cc-field" />
            </div>
            <div>
              <label class="cc-label" for="p-del">Entrega</label>
              <input id="p-del" v-model="deliveryDate" type="datetime-local" class="cc-field" />
            </div>
            <div>
              <label class="cc-label" for="p-dead">Cierre de participación</label>
              <input id="p-dead" v-model="deadline" type="datetime-local" class="cc-field" />
            </div>
          </div>
          <div class="mt-4">
            <label class="cc-label" for="p-ref">Referencia (opcional)</label>
            <input id="p-ref" v-model="reference" class="cc-field" placeholder="Se genera automáticamente" />
          </div>
        </section>

        <!-- 3. Cargo -->
        <section class="cc-card p-5">
          <h2 class="cc-h2 mb-4 flex items-center gap-2.5">
            <span class="flex size-6 items-center justify-center rounded-full bg-navy text-[11px] font-bold text-white">3</span>
            Equipo y mercancía
          </h2>
          <div class="grid gap-4 sm:grid-cols-[1fr_140px]">
            <div>
              <label class="cc-label" for="p-eq">Tipo de equipo</label>
              <select id="p-eq" v-model="equipmentType" class="cc-field">
                <option v-for="e in EQUIPMENT_TYPES" :key="e" :value="e">{{ e }}</option>
              </select>
            </div>
            <div>
              <label class="cc-label" for="p-units">Unidades</label>
              <input id="p-units" v-model.number="unitCount" type="number" min="1" class="cc-field" />
            </div>
            <div>
              <label class="cc-label" for="p-w">Peso (kg) {{ isLTL ? '*' : '' }}</label>
              <input id="p-w" v-model="weightText" type="number" min="0" inputmode="numeric" class="cc-field" placeholder="22,000" />
            </div>
            <div :class="!isLTL && 'sm:col-span-1'">
              <label class="cc-label" for="p-m">Medidas {{ isLTL ? '*' : '' }}</label>
              <input id="p-m" v-model="measurementsDesc" class="cc-field" placeholder="26 tarimas" />
            </div>
          </div>
          <div class="mt-4">
            <label class="cc-label" for="p-desc">Descripción de la mercancía</label>
            <textarea id="p-desc" v-model="merchandiseDesc" class="cc-field" placeholder="Ej. Electrodomésticos paletizados" />
          </div>
          <div class="mt-4">
            <p class="cc-label">Requisitos especiales</p>
            <div class="flex flex-wrap gap-1.5">
              <button
                v-for="req in SPECIAL_REQUIREMENTS"
                :key="req"
                type="button"
                class="cc-chip h-8 text-[12.5px]"
                :class="selectedRequirements.includes(req) && 'cc-chip-active'"
                @click="toggleReq(req)"
              >
                {{ req }}
              </button>
            </div>
          </div>
        </section>

        <!-- 4. Price -->
        <section v-if="!isLTL" class="cc-card p-5">
          <h2 class="cc-h2 mb-4 flex items-center gap-2.5">
            <span class="flex size-6 items-center justify-center rounded-full bg-navy text-[11px] font-bold text-white">4</span>
            Precio y condiciones
          </h2>
          <div class="grid gap-4 sm:grid-cols-[1fr_120px]">
            <div>
              <label class="cc-label" for="p-price">
                {{ assignmentMode === 'Subasta Inversa' ? 'Precio de referencia' : 'Precio por unidad' }} *
              </label>
              <div class="relative">
                <span class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm font-medium text-muted">$</span>
                <input
                  id="p-price"
                  v-model="priceText"
                  type="number"
                  min="0"
                  inputmode="numeric"
                  class="cc-field pl-8 text-lg font-semibold tabular-nums"
                  placeholder="0"
                />
              </div>
            </div>
            <div>
              <label class="cc-label" for="p-cur">Moneda</label>
              <select id="p-cur" v-model="currency" class="cc-field">
                <option value="MXN">MXN</option>
                <option value="USD">USD</option>
              </select>
            </div>
            <div>
              <label class="cc-label flex items-center gap-1.5" for="p-max">
                <Lock class="size-3.5 text-muted" aria-hidden="true" /> Máx. autorizado sin IVA
              </label>
              <div class="relative">
                <span class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm font-medium text-muted">$</span>
                <input id="p-max" v-model="maxPriceText" type="number" min="0" inputmode="numeric" class="cc-field pl-8 tabular-nums" placeholder="Opcional" />
              </div>
              <p class="cc-hint">Nunca se muestra al transportista.</p>
            </div>
            <div v-if="assignmentMode === 'Subasta Inversa'">
              <label class="cc-label" for="p-dec">Decremento mín.</label>
              <input id="p-dec" v-model="minDecrementText" type="number" min="0" class="cc-field" />
            </div>
          </div>
          <label class="cc-check mt-4">
            <input v-model="includesVAT" type="checkbox" />
            El precio incluye IVA
          </label>
          <div class="mt-4 grid gap-4 sm:grid-cols-2">
            <div>
              <label class="cc-label" for="p-inc">Conceptos incluidos</label>
              <input id="p-inc" v-model="includedConcepts" class="cc-field" placeholder="Flete, maniobras…" />
            </div>
            <div>
              <label class="cc-label" for="p-ext">Gastos extra permitidos</label>
              <input id="p-ext" v-model="allowedExtras" class="cc-field" placeholder="Casetas, estadías…" />
            </div>
          </div>
        </section>

        <!-- 5. Client -->
        <section v-if="!isLTL" class="cc-card p-5">
          <h2 class="cc-h2 flex items-center gap-2.5">
            <span class="flex size-6 items-center justify-center rounded-full bg-navy text-[11px] font-bold text-white">5</span>
            Cliente
            <span class="cc-badge bg-navy/[0.06] text-navy"><Lock class="size-3" aria-hidden="true" /> Privado</span>
          </h2>
          <p class="mb-4 mt-1 text-[13px] text-muted">Solo lo ven administradores y el transportista asignado.</p>
          <div class="grid gap-4 sm:grid-cols-2">
            <div>
              <label class="cc-label" for="p-cc">Contacto</label>
              <input id="p-cc" v-model="clientContact" class="cc-field" placeholder="Nombre" />
            </div>
            <div>
              <label class="cc-label" for="p-cp">Teléfono</label>
              <input id="p-cp" v-model="clientPhone" type="tel" class="cc-field" placeholder="10 dígitos" />
            </div>
            <div>
              <label class="cc-label" for="p-pa">Dirección de recolección</label>
              <input id="p-pa" v-model="pickupAddress" class="cc-field" />
            </div>
            <div>
              <label class="cc-label" for="p-da">Dirección de entrega</label>
              <input id="p-da" v-model="deliveryAddress" class="cc-field" />
            </div>
            <div class="sm:col-span-2">
              <label class="cc-label" for="p-obs">Observaciones</label>
              <textarea id="p-obs" v-model="observations" class="cc-field" />
            </div>
          </div>
        </section>

        <!-- Alerts -->
        <section class="cc-card p-5">
          <h2 class="cc-h2 mb-4">Canales de aviso</h2>
          <div class="grid grid-cols-2 gap-2 sm:grid-cols-4">
            <label v-for="c in channels" :key="c.label" class="cc-check flex-col items-start gap-2">
              <span class="flex w-full items-center justify-between">
                <component :is="c.icon" class="size-4 text-muted" aria-hidden="true" />
                <input v-model="c.model.value" type="checkbox" />
              </span>
              <span class="font-medium">{{ c.label }}</span>
            </label>
          </div>
        </section>
      </form>

      <Teleport to="body">
        <div
          class="fixed z-40 border-t border-line bg-card/95 backdrop-blur-xl"
          :style="publishBarStyle"
        >
          <div class="mx-auto flex max-w-3xl flex-col gap-2 px-4 py-3 sm:flex-row sm:items-center sm:gap-3 sm:px-6">
            <div class="min-w-0 flex-1">
              <p class="truncate text-sm font-semibold text-navy">{{ summary.route }}</p>
              <p v-if="error" class="text-xs font-medium text-danger">{{ error }}</p>
              <p v-else-if="missingFields.length" class="text-xs text-muted">
                Falta {{ missingFields.join(', ') }} para publicar
              </p>
              <p v-else class="truncate text-xs text-muted">
                {{ assignmentMode }} · {{ equipmentType }}
                <template v-if="summary.price"> · {{ summary.price }}</template>
              </p>
            </div>
            <button
              type="button"
              class="cc-btn w-full shrink-0 sm:w-auto sm:px-6"
              :disabled="!isValid || saving"
              @click="publish"
            >
              {{ saving ? 'Publicando…' : 'Publicar carga' }}
            </button>
          </div>
        </div>
      </Teleport>
    </template>
  </div>
</template>
