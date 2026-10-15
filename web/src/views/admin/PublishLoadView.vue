<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
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

const auth = useAuthStore();
const store = useDataStore();
const router = useRouter();

const published = ref(false);
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

function toggleReq(req: SpecialRequirement) {
  const i = selectedRequirements.value.indexOf(req);
  if (i >= 0) selectedRequirements.value.splice(i, 1);
  else selectedRequirements.value.push(req);
}

async function publish() {
  if (!isValid.value || !auth.currentUser) return;
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
      pickupDate: fromDatetimeLocalValue(pickupDate.value),
      deliveryDate: fromDatetimeLocalValue(deliveryDate.value),
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
      deadline: fromDatetimeLocalValue(deadline.value),
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
    publishedSummary.value = {
      reference: load.reference,
      route: `${load.originCity}, ${load.originState} → ${load.destinationCity}, ${load.destinationState}`,
      price: formatMoney(load.offeredPrice, load.currency),
      equipment: load.equipmentType,
    };
    published.value = true;
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
      <div class="cc-card p-8 text-center">
        <p class="text-sm font-medium text-success">Carga publicada</p>
        <h1 class="mt-2 text-xl font-bold text-navy">{{ publishedSummary.reference }}</h1>
        <p class="mt-2 text-sm text-muted">{{ publishedSummary.route }}</p>
        <p class="mt-1 text-sm text-muted">
          {{ publishedSummary.equipment }} · {{ publishedSummary.price }}
        </p>
        <div class="mt-6 flex flex-col gap-2 sm:flex-row sm:justify-center">
          <RouterLink
            :to="{ name: 'admin-loads' }"
            class="cc-btn h-11 w-auto px-6 text-sm sm:w-auto"
          >
            Ver cargas
          </RouterLink>
          <button
            type="button"
            class="cc-btn-secondary h-11 text-sm sm:w-auto sm:px-6"
            @click="published = false"
          >
            Publicar otra
          </button>
        </div>
      </div>
    </template>

    <template v-else>
      <h1 class="cc-h1 mb-5">Publicar carga</h1>
      <p v-if="error" class="mb-3 rounded-xl bg-danger-soft px-3 py-2 text-sm text-danger">
        {{ error }}
      </p>

      <form class="space-y-5" @submit.prevent="publish">
        <!-- Route -->
        <section class="cc-card p-4 md:p-5 space-y-3">
          <h2 class="text-sm font-semibold text-navy">Ruta</h2>
          <div>
            <label class="cc-label">Referencia (opcional)</label>
            <input v-model="reference" class="cc-field" placeholder="CC-2026-001" />
          </div>
          <div class="grid gap-3 sm:grid-cols-2">
            <div>
              <label class="cc-label">Ciudad origen *</label>
              <input v-model="originCity" class="cc-field" required />
            </div>
            <div>
              <label class="cc-label">País origen</label>
              <select v-model="originCountry" class="cc-field">
                <option value="mx">México</option>
                <option value="us">EE.UU.</option>
              </select>
            </div>
          </div>
          <div>
            <label class="cc-label">Estado origen</label>
            <select
              v-if="originCountry === 'mx'"
              v-model="originMXState"
              class="cc-field"
            >
              <option v-for="s in MEXICAN_STATES" :key="s" :value="s">{{ s }}</option>
            </select>
            <select v-else v-model="originUSState" class="cc-field">
              <option v-for="s in US_STATES" :key="s" :value="s">{{ s }}</option>
            </select>
          </div>
          <div class="grid gap-3 sm:grid-cols-2">
            <div>
              <label class="cc-label">Ciudad destino *</label>
              <input v-model="destinationCity" class="cc-field" required />
            </div>
            <div>
              <label class="cc-label">País destino</label>
              <select v-model="destinationCountry" class="cc-field">
                <option value="mx">México</option>
                <option value="us">EE.UU.</option>
              </select>
            </div>
          </div>
          <div>
            <label class="cc-label">Estado destino</label>
            <select
              v-if="destinationCountry === 'mx'"
              v-model="destinationMXState"
              class="cc-field"
            >
              <option v-for="s in MEXICAN_STATES" :key="s" :value="s">{{ s }}</option>
            </select>
            <select v-else v-model="destinationUSState" class="cc-field">
              <option v-for="s in US_STATES" :key="s" :value="s">{{ s }}</option>
            </select>
          </div>
          <div class="grid gap-3 sm:grid-cols-2">
            <div>
              <label class="cc-label">Recolección</label>
              <input v-model="pickupDate" type="datetime-local" class="cc-field" />
            </div>
            <div>
              <label class="cc-label">Entrega</label>
              <input v-model="deliveryDate" type="datetime-local" class="cc-field" />
            </div>
          </div>
        </section>

        <!-- Modality -->
        <section class="cc-card p-4 md:p-5 space-y-3">
          <h2 class="text-sm font-semibold text-navy">Modalidad</h2>
          <div>
            <label class="cc-label">Asignación</label>
            <select v-model="assignmentMode" class="cc-field">
              <option v-for="m in ASSIGNMENT_MODES" :key="m" :value="m">{{ m }}</option>
            </select>
          </div>
          <div>
            <label class="cc-label">Equipo</label>
            <select v-model="equipmentType" class="cc-field">
              <option v-for="e in EQUIPMENT_TYPES" :key="e" :value="e">{{ e }}</option>
            </select>
          </div>
          <div class="grid gap-3 sm:grid-cols-2">
            <div>
              <label class="cc-label">Unidades</label>
              <input v-model.number="unitCount" type="number" min="1" class="cc-field" />
            </div>
            <div>
              <label class="cc-label">Límite para participar</label>
              <input v-model="deadline" type="datetime-local" class="cc-field" />
            </div>
          </div>
        </section>

        <!-- Price -->
        <section
          v-if="!isLTL"
          class="cc-card p-4 md:p-5 space-y-3"
        >
          <h2 class="text-sm font-semibold text-navy">Precio</h2>
          <div class="grid gap-3 sm:grid-cols-2">
            <div>
              <label class="cc-label">Precio por unidad *</label>
              <input v-model="priceText" type="number" min="0" class="cc-field" />
            </div>
            <div>
              <label class="cc-label">Moneda</label>
              <select v-model="currency" class="cc-field">
                <option value="MXN">MXN</option>
                <option value="USD">USD</option>
              </select>
            </div>
          </div>
          <div>
            <label class="cc-label">Máx. autorizado sin IVA (opcional)</label>
            <input v-model="maxPriceText" type="number" min="0" class="cc-field" />
          </div>
          <label class="flex items-center gap-2 text-sm text-muted">
            <input v-model="includesVAT" type="checkbox" class="size-4" />
            IVA incluido
          </label>
          <div v-if="assignmentMode === 'Subasta Inversa'">
            <label class="cc-label">Decremento mínimo</label>
            <input v-model="minDecrementText" type="number" min="0" class="cc-field" />
          </div>
          <div>
            <label class="cc-label">Conceptos incluidos</label>
            <input v-model="includedConcepts" class="cc-field" />
          </div>
          <div>
            <label class="cc-label">Gastos extras permitidos</label>
            <input v-model="allowedExtras" class="cc-field" />
          </div>
        </section>

        <!-- Cargo -->
        <section class="cc-card p-4 md:p-5 space-y-3">
          <h2 class="text-sm font-semibold text-navy">Mercancía</h2>
          <div>
            <label class="cc-label">Peso (kg) {{ isLTL ? '*' : '' }}</label>
            <input v-model="weightText" type="number" min="0" class="cc-field" />
          </div>
          <div>
            <label class="cc-label">Descripción</label>
            <textarea v-model="merchandiseDesc" class="cc-field min-h-[80px]" />
          </div>
          <div v-if="isLTL">
            <label class="cc-label">Medidas *</label>
            <input v-model="measurementsDesc" class="cc-field" />
          </div>
          <div>
            <p class="cc-label">Requisitos especiales</p>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="req in SPECIAL_REQUIREMENTS"
                :key="req"
                type="button"
                class="rounded-full px-3 py-1 text-xs font-medium transition"
                :class="
                  selectedRequirements.includes(req)
                    ? 'bg-brand text-white'
                    : 'border border-line bg-background text-muted'
                "
                @click="toggleReq(req)"
              >
                {{ req }}
              </button>
            </div>
          </div>
        </section>

        <!-- Client (non-LTL) -->
        <section
          v-if="!isLTL"
          class="cc-card p-4 md:p-5 space-y-3"
        >
          <h2 class="text-sm font-semibold text-navy">Cliente (privado)</h2>
          <p class="text-xs text-muted">
            Solo visible para admin y transportista asignado.
          </p>
          <div class="grid gap-3 sm:grid-cols-2">
            <div>
              <label class="cc-label">Contacto</label>
              <input v-model="clientContact" class="cc-field" />
            </div>
            <div>
              <label class="cc-label">Teléfono</label>
              <input v-model="clientPhone" class="cc-field" />
            </div>
          </div>
          <div>
            <label class="cc-label">Dirección recolección</label>
            <input v-model="pickupAddress" class="cc-field" />
          </div>
          <div>
            <label class="cc-label">Dirección entrega</label>
            <input v-model="deliveryAddress" class="cc-field" />
          </div>
          <div>
            <label class="cc-label">Observaciones</label>
            <textarea v-model="observations" class="cc-field min-h-[72px]" />
          </div>
        </section>

        <!-- Alerts -->
        <section class="cc-card p-4 md:p-5 space-y-2">
          <h2 class="text-sm font-semibold text-navy">Canales de aviso</h2>
          <label class="flex items-center gap-2 text-sm"
            ><input v-model="notifyInApp" type="checkbox" class="size-4" /> En app</label
          >
          <label class="flex items-center gap-2 text-sm"
            ><input v-model="notifyEmail" type="checkbox" class="size-4" /> Correo</label
          >
          <label class="flex items-center gap-2 text-sm"
            ><input v-model="notifyWhatsApp" type="checkbox" class="size-4" /> WhatsApp</label
          >
          <label class="flex items-center gap-2 text-sm"
            ><input v-model="notifyAICall" type="checkbox" class="size-4" /> Llamada IA</label
          >
        </section>

        <button type="submit" class="cc-btn" :disabled="!isValid || saving">
          {{ saving ? 'Publicando…' : 'Publicar carga' }}
        </button>
      </form>
    </template>
  </div>
</template>
