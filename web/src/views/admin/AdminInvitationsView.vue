<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { Mail, MessageCircle, Send } from '@lucide/vue';
import { useAuthStore } from '@/stores/auth';
import {
  saveManualPreProfileAndInvite,
  upsertDemoRecord,
} from '@/lib/directory';
import { EQUIPMENT_TYPES, MEXICAN_ZONES, phoneDigits } from '@/lib/models';
import PageHeader from '@/components/PageHeader.vue';
import ResultState from '@/components/ResultState.vue';
import FormSwitch from '@/components/FormSwitch.vue';
import MexicoZoneMap from '@/components/MexicoZoneMap.vue';
import USAZoneGrid from '@/components/USAZoneGrid.vue';
import { USA_MAP_ZONES } from '@/lib/zone-maps';
import { toast } from '@/lib/toast';

const auth = useAuthStore();
const router = useRouter();
const isDemo = computed(() => auth.currentUser?.email === 'demo@continente.local');
const directoryRoute = computed(() =>
  auth.currentUser?.role === 'pricer' ? 'pricer-directory' : 'admin-directory',
);

const step = ref<1 | 2>(1);
const sending = ref(false);
const sent = ref(false);

const form = reactive({
  companyName: '',
  contactName: '',
  baseCity: '',
  phone: '',
  email: '',
  handlesLTL: false,
  handlesLocal: false,
  handlesIntraState: false,
  coversUSA: false,
  equipment: [] as string[],
});

const selectedStates = ref<Set<string>>(new Set());
const usaStates = ref<Set<string>>(new Set());

watch(
  () => form.coversUSA,
  (on) => {
    if (on && usaStates.value.size === 0) {
      usaStates.value = new Set(USA_MAP_ZONES.flatMap((zone) => [...zone.states]));
    }
  },
);

const digits = computed(() => phoneDigits(form.phone));
const hasPhone = computed(() => digits.value.length === 10);
const hasEmail = computed(() => form.email.includes('@'));
const basicValid = computed(
  () => (form.contactName.trim() || form.companyName.trim()) && (hasPhone.value || hasEmail.value),
);
const displayName = computed(() => form.companyName.trim() || form.contactName.trim());

function zonesFromStates(states: Set<string>): string[] {
  return MEXICAN_ZONES.filter((zone) => zone.states.some((state) => states.has(state))).map(
    (zone) => zone.id,
  );
}

function toggle(list: string[], value: string) {
  const idx = list.indexOf(value);
  if (idx >= 0) list.splice(idx, 1);
  else list.push(value);
}

async function send() {
  sending.value = true;
  try {
    const input = {
      contactName: form.contactName.trim(),
      companyName: form.companyName.trim(),
      phone: digits.value,
      email: form.email.trim().toLowerCase(),
      baseCity: form.baseCity.trim(),
      equipmentTypes: [...form.equipment],
      coverageZones: zonesFromStates(selectedStates.value),
      coverageStates: [...selectedStates.value],
      handlesLTL: form.handlesLTL,
      handlesLocal: form.handlesLocal,
      handlesIntraState: form.handlesIntraState,
      coversUSA: form.coversUSA,
      coverageUSAStates: form.coversUSA ? [...usaStates.value] : [],
    };
    if (isDemo.value) {
      if (input.phone) {
        upsertDemoRecord({
          id: input.phone,
          companyName: input.companyName || input.contactName,
          contactName: input.contactName,
          phone: input.phone,
          email: input.email,
          baseCity: input.baseCity,
          equipmentTypes: input.equipmentTypes,
          coverageZones: input.coverageZones,
          handlesLTL: input.handlesLTL,
          status: 'pending_invitation',
          registered: false,
        });
      }
    } else {
      const pricerEmail =
        auth.currentUser?.role === 'pricer' ? auth.currentUser.email : undefined;
      await saveManualPreProfileAndInvite(input, auth.currentUser?.uuid ?? '', pricerEmail);
    }
    sent.value = true;
    toast.success('Invitación enviada', displayName.value);
  } catch (e) {
    toast.error('No se pudo guardar', e instanceof Error ? e.message : undefined);
    step.value = 1;
  } finally {
    sending.value = false;
  }
}
</script>

<template>
  <div class="cc-page">
    <PageHeader
      title="Invitación manual"
      subtitle="El transportista solo confirma sus datos y elige una contraseña"
      :back="{ name: directoryRoute }"
      back-label="Directorio"
    />

    <ResultState
      v-if="sent"
      ok
      title="Invitación enviada"
      :body="`${displayName} recibirá las instrucciones para completar su registro.`"
      action-label="Volver al directorio"
      @action="router.push({ name: directoryRoute })"
    />

    <form v-else class="mx-auto max-w-2xl space-y-5" @submit.prevent="step === 1 ? (step = 2) : send()">
      <ol class="flex items-center gap-3 text-sm font-medium">
        <li class="flex items-center gap-2" :class="step === 1 ? 'text-brand' : 'text-muted'">
          <span class="flex size-6 items-center justify-center rounded-full text-xs" :class="step === 1 ? 'bg-brand text-white' : 'bg-success text-white'">1</span>
          Datos
        </li>
        <li class="h-px flex-1 bg-line" />
        <li class="flex items-center gap-2" :class="step === 2 ? 'text-brand' : 'text-muted'">
          <span class="flex size-6 items-center justify-center rounded-full text-xs" :class="step === 2 ? 'bg-brand text-white' : 'bg-background text-muted'">2</span>
          Cobertura
        </li>
      </ol>

      <section v-if="step === 1" class="cc-card space-y-4 p-5">
        <h2 class="cc-h2">Datos del transportista</h2>
        <div>
          <label class="cc-label" for="co">Empresa / razón social</label>
          <input id="co" v-model="form.companyName" class="cc-field" />
        </div>
        <div>
          <label class="cc-label" for="contact">Nombre del contacto</label>
          <input id="contact" v-model="form.contactName" class="cc-field" />
        </div>
        <div>
          <label class="cc-label" for="city">Ciudad / patio base</label>
          <input id="city" v-model="form.baseCity" class="cc-field" />
        </div>
        <h2 class="cc-h2 pt-2">Contacto</h2>
        <div>
          <label class="cc-label" for="phone">WhatsApp / teléfono</label>
          <input id="phone" v-model="form.phone" type="tel" inputmode="numeric" class="cc-field" placeholder="10 dígitos" />
          <p v-if="form.phone && !hasPhone" class="cc-hint text-danger">
            Se requieren 10 dígitos ({{ digits.length }}/10)
          </p>
        </div>
        <div>
          <label class="cc-label" for="email">Correo electrónico</label>
          <input id="email" v-model="form.email" type="email" class="cc-field" />
        </div>
        <p v-if="hasPhone || hasEmail" class="flex flex-wrap items-center gap-2 text-xs text-muted">
          Se enviará por
          <span v-if="hasPhone" class="cc-badge bg-success-soft text-success">
            <MessageCircle class="size-3" aria-hidden="true" /> WhatsApp
          </span>
          <span v-if="hasEmail" class="cc-badge bg-blue-soft text-blue-ink">
            <Mail class="size-3" aria-hidden="true" /> Correo
          </span>
        </p>
        <div class="space-y-3 pt-1">
          <h2 class="cc-h2">Capacidades</h2>
          <label class="flex items-start gap-3 text-sm">
            <input v-model="form.handlesLTL" type="checkbox" class="mt-1 size-4" />
            <span><span class="font-medium text-navy">Carga consolidada (LTL)</span><span class="block text-xs text-muted">Acepta cargas parciales</span></span>
          </label>
          <label class="flex items-start gap-3 text-sm">
            <input v-model="form.handlesLocal" type="checkbox" class="mt-1 size-4" />
            <span><span class="font-medium text-navy">Rutas locales</span><span class="block text-xs text-muted">Misma ciudad o zona metropolitana</span></span>
          </label>
          <label class="flex items-start gap-3 text-sm">
            <input v-model="form.handlesIntraState" type="checkbox" class="mt-1 size-4" />
            <span><span class="font-medium text-navy">Rutas intraestatales</span><span class="block text-xs text-muted">Entre ciudades del mismo estado</span></span>
          </label>
        </div>
        <button type="submit" class="cc-btn" :disabled="!basicValid">Siguiente: cobertura y equipo</button>
        <p class="text-center text-[11px] text-muted">
          La cobertura es opcional. El transportista puede completarla al registrarse.
        </p>
      </section>

      <section v-else class="cc-card space-y-4 p-5">
        <h2 class="cc-h2">Equipo</h2>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="eq in EQUIPMENT_TYPES"
            :key="eq"
            type="button"
            class="cc-chip"
            :class="form.equipment.includes(eq) && 'cc-chip-active'"
            @click="toggle(form.equipment, eq)"
          >
            {{ eq }}
          </button>
        </div>
        <h2 class="cc-h2">Zonas de cobertura</h2>
        <p class="text-xs text-muted">
          Toca una zona para agregar todos sus estados. Quita los que este transportista no cubra.
        </p>
        <MexicoZoneMap v-model="selectedStates" />
        <FormSwitch
          v-model="form.coversUSA"
          title="También cubre Estados Unidos"
          hint="Activa para ver las zonas y quitar los estados que no cubre."
          label="También cubre Estados Unidos"
        />
        <USAZoneGrid v-if="form.coversUSA" v-model="usaStates" />
        <p v-if="!form.equipment.length && !selectedStates.size" class="text-xs text-muted">
          Puedes enviar sin cobertura. El transportista la completará al registrarse.
        </p>
        <div class="flex gap-2">
          <button type="button" class="cc-btn-secondary" @click="step = 1">Atrás</button>
          <button type="submit" class="cc-btn" :disabled="sending">
            <Send class="size-4" aria-hidden="true" />
            {{ sending ? 'Enviando…' : 'Enviar invitación' }}
          </button>
        </div>
      </section>
    </form>
  </div>
</template>
