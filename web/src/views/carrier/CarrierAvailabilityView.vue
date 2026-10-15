<script setup lang="ts">
import { reactive, ref } from 'vue';
import { useDataStore } from '@/stores/data';
import { EQUIPMENT_TYPES, MEXICAN_STATES, type EquipmentType } from '@/lib/models';

const store = useDataStore();
const msg = ref('');
const form = reactive({
  equipmentType: EQUIPMENT_TYPES[0] as EquipmentType,
  originState: 'N.L.',
  destinationState: 'CDMX',
  count: 1,
});

async function publish() {
  await store.postQuickAvailability(
    form.equipmentType,
    form.count,
    form.originState,
    form.destinationState,
  );
  msg.value = 'Disponibilidad publicada';
}
</script>

<template>
  <div class="mx-auto w-full max-w-xl px-4 py-6 sm:px-6">
    <h1 class="text-2xl font-bold text-navy">Publicar disponibilidad</h1>
    <p class="mt-1 text-sm text-muted">Misma lógica que AvailabilityView en iOS</p>
    <form class="mt-5 space-y-3" @submit.prevent="publish">
      <div>
        <label class="cc-label">Equipo</label>
        <select v-model="form.equipmentType" class="cc-field">
          <option v-for="e in EQUIPMENT_TYPES" :key="e" :value="e">{{ e }}</option>
        </select>
      </div>
      <div>
        <label class="cc-label">Origen</label>
        <select v-model="form.originState" class="cc-field">
          <option v-for="s in MEXICAN_STATES" :key="s" :value="s">{{ s }}</option>
        </select>
      </div>
      <div>
        <label class="cc-label">Destino preferido</label>
        <select v-model="form.destinationState" class="cc-field">
          <option v-for="s in MEXICAN_STATES" :key="'d' + s" :value="s">{{ s }}</option>
        </select>
      </div>
      <div>
        <label class="cc-label">Unidades disponibles</label>
        <input v-model.number="form.count" type="number" min="1" class="cc-field" />
      </div>
      <p v-if="msg" class="text-sm text-success">{{ msg }}</p>
      <button type="submit" class="cc-btn">Publicar</button>
    </form>
  </div>
</template>
