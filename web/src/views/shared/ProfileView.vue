<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';
import {
  EQUIPMENT_TYPES,
  MEXICAN_STATES,
  newUuid,
  type CarrierRoute,
  type EquipmentType,
} from '@/lib/models';

const auth = useAuthStore();
const store = useDataStore();
const router = useRouter();

const user = computed(() => auth.currentUser);
const isCarrier = computed(
  () => user.value?.role === 'carrier' || user.value?.role === 'independent_operator',
);

const handlesLTL = ref(user.value?.handlesLTL ?? false);
const routes = ref<CarrierRoute[]>([...(user.value?.routes ?? [])]);
const saving = ref(false);
const message = ref('');
const error = ref('');

const newOrigin = ref('N.L.');
const newDest = ref('CDMX');
const newBidirectional = ref(true);
const newEquipment = ref<EquipmentType[]>([]);

const roleLabel = computed(() => {
  switch (user.value?.role) {
    case 'admin':
      return 'Administrador';
    case 'carrier':
      return 'Línea transportista';
    case 'independent_operator':
      return 'Operador independiente';
    default:
      return '';
  }
});

function toggleEq(eq: EquipmentType) {
  const i = newEquipment.value.indexOf(eq);
  if (i >= 0) newEquipment.value.splice(i, 1);
  else newEquipment.value.push(eq);
}

function addRoute() {
  if (!newOrigin.value || !newDest.value) return;
  routes.value.push({
    id: newUuid(),
    originState: newOrigin.value,
    destinationState: newDest.value,
    bidirectional: newBidirectional.value,
    equipmentTypes: [...newEquipment.value],
  });
  newEquipment.value = [];
}

function removeRoute(id: string) {
  routes.value = routes.value.filter((r) => r.id !== id);
}

async function saveRoutes() {
  saving.value = true;
  message.value = '';
  error.value = '';
  try {
    await store.updateCarrierRoutes(routes.value);
    message.value = 'Rutas actualizadas';
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'No se pudieron guardar las rutas';
  } finally {
    saving.value = false;
  }
}

async function toggleLTL() {
  handlesLTL.value = !handlesLTL.value;
  await store.setHandlesLTL(handlesLTL.value);
}

async function logout() {
  await auth.logout();
  await router.push({ name: 'login' });
}
</script>

<template>
  <div class="cc-page-narrow">
    <h1 class="cc-h1 mb-5">Perfil</h1>

    <section v-if="user" class="mb-5 cc-card p-4 md:p-5">
      <p class="text-lg font-semibold text-navy">{{ user.name }}</p>
      <p class="text-sm text-muted">{{ roleLabel }}</p>
      <dl class="mt-4 space-y-2 text-sm">
        <div class="flex justify-between gap-4">
          <dt class="text-muted">Correo</dt>
          <dd>{{ user.email }}</dd>
        </div>
        <div class="flex justify-between gap-4">
          <dt class="text-muted">Teléfono</dt>
          <dd>{{ user.phone }}</dd>
        </div>
        <div class="flex justify-between gap-4">
          <dt class="text-muted">Estado</dt>
          <dd>{{ user.status }}</dd>
        </div>
      </dl>
    </section>

    <section
      v-if="isCarrier && user?.role === 'carrier'"
      class="mb-5 cc-card p-4 md:p-5"
    >
      <div class="flex items-center justify-between gap-3">
        <div>
          <h2 class="text-sm font-semibold text-navy">Opero cargas LTL</h2>
          <p class="text-xs text-muted">Visible en marketplace consolidado</p>
        </div>
        <button
          type="button"
          class="relative h-7 w-12 rounded-full transition"
          :class="handlesLTL ? 'bg-brand' : 'bg-line'"
          @click="toggleLTL"
        >
          <span
            class="absolute top-0.5 size-6 rounded-full bg-white shadow transition"
            :class="handlesLTL ? 'left-5' : 'left-0.5'"
          />
        </button>
      </div>
    </section>

    <section v-if="isCarrier" class="mb-5 cc-card p-4 md:p-5">
      <h2 class="mb-1 text-sm font-semibold text-navy">Mis rutas</h2>
      <p class="mb-3 text-xs text-muted">
        Al definir rutas explícitas, se limpian cobertura por estados/zonas.
      </p>

      <p v-if="message" class="mb-2 text-sm text-success">{{ message }}</p>
      <p v-if="error" class="mb-2 text-sm text-danger">{{ error }}</p>

      <ul v-if="routes.length" class="mb-4 space-y-2">
        <li
          v-for="r in routes"
          :key="r.id"
          class="flex items-start justify-between gap-2 rounded-xl bg-background px-3 py-2 text-sm"
        >
          <div>
            <p class="font-medium text-navy">
              {{ r.originState }} {{ r.bidirectional ? '↔' : '→' }} {{ r.destinationState }}
            </p>
            <p class="text-xs text-muted">
              {{
                r.equipmentTypes.length
                  ? r.equipmentTypes.join(', ')
                  : 'Cualquier equipo'
              }}
            </p>
          </div>
          <button
            type="button"
            class="text-xs font-medium text-danger"
            @click="removeRoute(r.id)"
          >
            Quitar
          </button>
        </li>
      </ul>
      <p v-else class="mb-4 text-sm text-muted">Sin rutas explícitas.</p>

      <div class="space-y-2 rounded-xl border border-dashed border-line p-3">
        <p class="text-xs font-semibold text-navy">Agregar ruta</p>
        <div class="grid gap-2 sm:grid-cols-2">
          <select v-model="newOrigin" class="cc-field py-2 text-sm">
            <option v-for="s in MEXICAN_STATES" :key="s" :value="s">{{ s }}</option>
          </select>
          <select v-model="newDest" class="cc-field py-2 text-sm">
            <option v-for="s in MEXICAN_STATES" :key="`d-${s}`" :value="s">{{ s }}</option>
          </select>
        </div>
        <label class="flex items-center gap-2 text-xs text-muted">
          <input v-model="newBidirectional" type="checkbox" class="size-4" />
          Bidireccional
        </label>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="eq in EQUIPMENT_TYPES"
            :key="eq"
            type="button"
            class="rounded-full px-2 py-0.5 text-[10px] font-medium"
            :class="
              newEquipment.includes(eq)
                ? 'bg-brand text-white'
                : 'border border-line text-muted'
            "
            @click="toggleEq(eq)"
          >
            {{ eq }}
          </button>
        </div>
        <button type="button" class="cc-btn-secondary h-9 text-sm" @click="addRoute">
          Agregar a la lista
        </button>
      </div>

      <button
        type="button"
        class="cc-btn mt-4 h-10 text-sm"
        :disabled="saving"
        @click="saveRoutes"
      >
        {{ saving ? 'Guardando…' : 'Guardar rutas' }}
      </button>
    </section>

    <button
      type="button"
      class="w-full rounded-[10px] border border-danger/30 bg-danger-soft px-4 py-3 text-sm font-semibold text-danger"
      @click="logout"
    >
      Cerrar sesión
    </button>
  </div>
</template>
