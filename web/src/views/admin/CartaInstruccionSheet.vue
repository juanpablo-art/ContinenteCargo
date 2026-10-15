<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { FileText, Paperclip } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import type { Load } from '@/lib/models';
import { phoneDigits } from '@/lib/models';
import { formatDateTime } from '@/lib/format';
import { toast } from '@/lib/toast';
import SheetModal from '@/components/SheetModal.vue';

const props = defineProps<{ open: boolean; load: Load }>();
const emit = defineEmits<{ close: [] }>();

const store = useDataStore();
const folio = ref('');
const instruccionesRecoleccion = ref('');
const instruccionesEntrega = ref('');
const contactoCarga = ref('');
const contactoDescarga = ref('');
const observaciones = ref('');
const archivoNombre = ref('');
const saved = ref(false);
const saving = ref(false);

watch(
  () => [props.open, props.load.id, props.load.cartaInstruccion?.creadaAt] as const,
  () => {
    if (!props.open) return;
    const ci = props.load.cartaInstruccion;
    folio.value = ci?.folio ?? '';
    instruccionesRecoleccion.value = ci?.instruccionesRecoleccion ?? '';
    instruccionesEntrega.value = ci?.instruccionesEntrega ?? '';
    contactoCarga.value = ci?.contactoCarga ?? props.load.clientContactName;
    contactoDescarga.value = ci?.contactoDescarga ?? '';
    observaciones.value = ci?.observaciones ?? props.load.observations;
    archivoNombre.value = ci?.archivoNombre ?? '';
    saved.value = false;
  },
  { immediate: true },
);

const carriers = computed(() =>
  props.load.confirmedCarrierIds
    .map((id) => store.users.find((u) => u.uuid === id))
    .filter((u): u is NonNullable<typeof u> => Boolean(u)),
);

function onFile(event: Event) {
  const file = (event.target as HTMLInputElement).files?.[0];
  archivoNombre.value = file?.name ?? '';
  saved.value = false;
}

function buildText() {
  const load = props.load;
  const lines = ['CARTA INSTRUCCIÓN', '================='];
  if (folio.value) lines.push(`Folio: ${folio.value}`);
  lines.push(`Referencia: ${load.reference}`);
  lines.push(`Fecha: ${formatDateTime(load.pickupDate)}`);
  lines.push('', 'RUTA', `Origen: ${load.originCity}, ${load.originState}`);
  if (load.exactPickupAddress) lines.push(`Dirección de carga: ${load.exactPickupAddress}`);
  lines.push(`Destino: ${load.destinationCity}, ${load.destinationState}`);
  if (load.exactDeliveryAddress) lines.push(`Dirección de descarga: ${load.exactDeliveryAddress}`);
  lines.push(`Recolección: ${formatDateTime(load.pickupDate)}`);
  lines.push(`Entrega: ${formatDateTime(load.deliveryDate)}`);
  if (contactoCarga.value) lines.push('', `Contacto en carga: ${contactoCarga.value}`);
  if (load.clientContactPhone) lines.push(`Tel. cliente: ${load.clientContactPhone}`);
  if (contactoDescarga.value) lines.push(`Contacto en descarga: ${contactoDescarga.value}`);
  if (instruccionesRecoleccion.value) {
    lines.push('', 'INSTRUCCIONES DE RECOLECCIÓN', instruccionesRecoleccion.value);
  }
  if (instruccionesEntrega.value) {
    lines.push('', 'INSTRUCCIONES DE ENTREGA', instruccionesEntrega.value);
  }
  if (observaciones.value) lines.push('', 'OBSERVACIONES', observaciones.value);
  lines.push('', 'Continente Cargo');
  return lines.join('\n');
}

async function persist() {
  saving.value = true;
  try {
    await store.saveCartaInstruccion(props.load.id, {
      folio: folio.value.trim(),
      instruccionesRecoleccion: instruccionesRecoleccion.value.trim(),
      instruccionesEntrega: instruccionesEntrega.value.trim(),
      contactoCarga: contactoCarga.value.trim(),
      contactoDescarga: contactoDescarga.value.trim(),
      observaciones: observaciones.value.trim(),
      archivoNombre: archivoNombre.value,
      creadaAt: props.load.cartaInstruccion?.creadaAt ?? new Date(),
    });
    saved.value = true;
    toast.success('Carta de instrucción guardada');
  } catch (e) {
    toast.error('No se pudo guardar la carta', e instanceof Error ? e.message : undefined);
  } finally {
    saving.value = false;
  }
}

function whatsApp(phone: string) {
  void persist();
  const digits = phoneDigits(phone);
  const url = `https://wa.me/${digits}?text=${encodeURIComponent(buildText())}`;
  window.open(url, '_blank', 'noopener');
}

function mail(email: string) {
  void persist();
  const subject = encodeURIComponent(`Carta Instrucción – ${props.load.reference}`);
  const body = encodeURIComponent(buildText());
  window.location.href = `mailto:${email}?subject=${subject}&body=${body}`;
}
</script>

<template>
  <SheetModal
    :open="open"
    title="Carta de instrucción"
    :subtitle="load.reference"
    @close="emit('close')"
  >
    <div class="space-y-4">
      <div class="rounded-xl bg-background p-3 text-sm">
        <p class="font-semibold text-navy">
          {{ load.originCity }} → {{ load.destinationCity }}
        </p>
        <p class="mt-1 text-xs text-muted">
          Recolección {{ formatDateTime(load.pickupDate) }} · entrega {{ formatDateTime(load.deliveryDate) }}
        </p>
      </div>

      <div>
        <label class="cc-label" for="ci-folio">Folio</label>
        <input id="ci-folio" v-model="folio" class="cc-field" @input="saved = false" />
      </div>
      <div>
        <label class="cc-label" for="ci-pick">Instrucciones de recolección</label>
        <textarea id="ci-pick" v-model="instruccionesRecoleccion" rows="3" class="cc-field" @input="saved = false" />
      </div>
      <div>
        <label class="cc-label" for="ci-drop">Instrucciones de entrega</label>
        <textarea id="ci-drop" v-model="instruccionesEntrega" rows="3" class="cc-field" @input="saved = false" />
      </div>
      <div class="grid gap-3 sm:grid-cols-2">
        <div>
          <label class="cc-label" for="ci-c1">Contacto en carga</label>
          <input id="ci-c1" v-model="contactoCarga" class="cc-field" @input="saved = false" />
        </div>
        <div>
          <label class="cc-label" for="ci-c2">Contacto en descarga</label>
          <input id="ci-c2" v-model="contactoDescarga" class="cc-field" @input="saved = false" />
        </div>
      </div>
      <div>
        <label class="cc-label" for="ci-notes">Observaciones</label>
        <textarea id="ci-notes" v-model="observaciones" rows="2" class="cc-field" @input="saved = false" />
      </div>

      <div>
        <p class="cc-label flex items-center gap-1.5">
          <Paperclip class="size-3.5" aria-hidden="true" /> Archivo adjunto
        </p>
        <p v-if="archivoNombre" class="mb-2 text-sm font-medium text-navy">{{ archivoNombre }}</p>
        <input type="file" accept="application/pdf,image/*" class="text-sm text-muted" @change="onFile" />
      </div>

      <div v-if="carriers.length" class="space-y-2">
        <p class="text-sm font-semibold text-navy">Enviar a transportistas confirmados</p>
        <div v-for="carrier in carriers" :key="carrier.uuid" class="rounded-xl bg-background p-3">
          <p class="text-sm font-semibold text-navy">{{ carrier.name }}</p>
          <p class="text-xs text-muted">{{ carrier.email }} · {{ carrier.phone }}</p>
          <div class="mt-2 flex gap-2">
            <button type="button" class="cc-btn h-9 flex-1 bg-[#3cbc54] shadow-none hover:bg-[#34a84a]" @click="whatsApp(carrier.phone)">
              WhatsApp
            </button>
            <button type="button" class="cc-btn-secondary h-9 flex-1" @click="mail(carrier.email)">
              Correo
            </button>
          </div>
        </div>
      </div>
      <p v-else class="rounded-xl bg-background px-3 py-2.5 text-xs text-muted">
        Cuando los transportistas confirmen unidades aparecerán aquí para enviarles la carta.
      </p>
    </div>

    <template #footer>
      <button type="button" class="cc-btn" :disabled="saving" @click="persist">
        <FileText class="size-4" aria-hidden="true" />
        {{ saved ? 'Guardado' : saving ? 'Guardando…' : 'Guardar carta de instrucción' }}
      </button>
    </template>
  </SheetModal>
</template>
