<script setup lang="ts">
import { computed, reactive, ref } from 'vue';
import { Radio, Minus, Plus, Trash2, ArrowDown, Zap } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import { EQUIPMENT_TYPES, MEXICAN_STATES, type EquipmentType } from '@/lib/models';
import { formatDateTime } from '@/lib/format';
import { toast } from '@/lib/toast';
import PageHeader from '@/components/PageHeader.vue';

const store = useDataStore();
const busy = ref(false);
const form = reactive({
  equipmentType: EQUIPMENT_TYPES[0] as EquipmentType,
  originState: 'N.L.',
  destinationState: 'CDMX',
  count: 1,
});

const posts = computed(() =>
  store
    .myUnits()
    .filter((u) => u.notes === 'availability_post')
    .sort((a, b) => b.availableFrom.getTime() - a.availableFrom.getTime()),
);

async function publish() {
  busy.value = true;
  try {
    await store.postQuickAvailability(
      form.equipmentType,
      form.count,
      form.originState,
      form.destinationState,
    );
    toast.success(
      'Disponibilidad publicada',
      `${form.count} × ${form.equipmentType} · ${form.originState} → ${form.destinationState}`,
    );
  } catch (e) {
    toast.error('No se pudo publicar', e instanceof Error ? e.message : undefined);
  } finally {
    busy.value = false;
  }
}

async function remove(id: string) {
  try {
    await store.deleteUnit(id);
    toast.success('Publicación retirada');
  } catch (e) {
    toast.error('No se pudo retirar', e instanceof Error ? e.message : undefined);
  }
}
</script>

<template>
  <div class="cc-page">
    <PageHeader
      title="Disponibilidad"
      subtitle="Avisa a Continente Cargo que tienes unidades libres para recibir cargas a tu medida"
    />

    <div class="grid gap-5 lg:grid-cols-[minmax(0,440px)_minmax(0,1fr)] lg:items-start">
      <form class="cc-card overflow-hidden" @submit.prevent="publish">
        <div class="flex items-center gap-3 border-b border-line bg-background/50 px-5 py-4">
          <span class="cc-icon-tile size-9"><Zap class="size-[18px]" aria-hidden="true" /></span>
          <div>
            <h2 class="cc-h2">Publicación rápida</h2>
            <p class="text-xs text-muted">Toma menos de 10 segundos</p>
          </div>
        </div>
        <div class="space-y-5 p-5">
          <div>
            <label class="cc-label" for="av-eq">Tipo de equipo</label>
            <select id="av-eq" v-model="form.equipmentType" class="cc-field">
              <option v-for="e in EQUIPMENT_TYPES" :key="e" :value="e">{{ e }}</option>
            </select>
          </div>

          <div class="rounded-2xl border border-line p-3">
            <div>
              <label class="cc-label flex items-center gap-2" for="av-o">
                <span class="size-2.5 rounded-full border-2 border-brand" /> ¿Dónde está tu unidad?
              </label>
              <select id="av-o" v-model="form.originState" class="cc-field">
                <option v-for="s in MEXICAN_STATES" :key="s" :value="s">{{ s }}</option>
              </select>
            </div>
            <div class="flex justify-center py-1.5 text-muted" aria-hidden="true">
              <ArrowDown class="size-4" />
            </div>
            <div>
              <label class="cc-label flex items-center gap-2" for="av-d">
                <span class="size-2.5 rounded-full bg-orange" /> Destino preferido
              </label>
              <select id="av-d" v-model="form.destinationState" class="cc-field">
                <option v-for="s in MEXICAN_STATES" :key="'d' + s" :value="s">{{ s }}</option>
              </select>
            </div>
          </div>

          <div>
            <span class="cc-label">Unidades disponibles</span>
            <div class="flex items-center gap-3">
              <button
                type="button"
                class="cc-btn-secondary size-11 w-11 shrink-0 px-0"
                :disabled="form.count <= 1"
                aria-label="Menos"
                @click="form.count--"
              >
                <Minus class="size-4" />
              </button>
              <input
                v-model.number="form.count"
                type="number"
                min="1"
                class="cc-field text-center text-lg font-bold tabular-nums"
                aria-label="Unidades"
              />
              <button
                type="button"
                class="cc-btn-secondary size-11 w-11 shrink-0 px-0"
                aria-label="Más"
                @click="form.count++"
              >
                <Plus class="size-4" />
              </button>
            </div>
          </div>

          <button type="submit" class="cc-btn h-12" :disabled="busy || form.count < 1">
            <Radio class="size-4" aria-hidden="true" />
            {{ busy ? 'Publicando…' : 'Publicar disponibilidad' }}
          </button>
        </div>
      </form>

      <section class="min-w-0">
        <div class="mb-3 flex items-center justify-between">
          <h2 class="cc-h2">Tus publicaciones</h2>
          <span class="text-xs font-medium text-muted">{{ posts.length }}</span>
        </div>
        <div v-if="!posts.length" class="rounded-2xl border border-dashed border-line px-6 py-12 text-center">
          <Radio class="mx-auto size-6 text-muted" aria-hidden="true" />
          <p class="mt-3 text-sm font-semibold text-navy">Sin publicaciones activas</p>
          <p class="mt-1 text-[13px] text-muted">Lo que publiques aparecerá aquí.</p>
        </div>
        <div v-else class="space-y-2.5">
          <article
            v-for="p in posts"
            :key="p.id"
            class="cc-card flex items-center gap-3 p-4"
          >
            <span class="cc-icon-tile"><Zap class="size-[18px]" aria-hidden="true" /></span>
            <div class="min-w-0 flex-1">
              <p class="truncate text-sm font-semibold text-navy">
                {{ p.currentLocation }} → {{ p.coverageZones[0] || 'Cualquier destino' }}
              </p>
              <p class="mt-0.5 truncate text-xs text-muted">
                {{ Number(p.trailerNumber) || 1 }} × {{ p.equipmentType }} ·
                {{ formatDateTime(p.availableFrom) }}
              </p>
            </div>
            <button
              type="button"
              class="flex size-9 shrink-0 items-center justify-center rounded-lg text-muted transition hover:bg-danger-soft hover:text-danger"
              aria-label="Retirar publicación"
              @click="remove(p.id)"
            >
              <Trash2 class="size-4" />
            </button>
          </article>
        </div>
      </section>
    </div>
  </div>
</template>
