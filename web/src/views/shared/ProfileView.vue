<script setup lang="ts">
import { computed, reactive, ref } from 'vue';
import { useRouter } from 'vue-router';
import { doc, updateDoc } from 'firebase/firestore';
import { auth as fbAuth, db } from '@/plugins/firebase';
import { useAuthStore } from '@/stores/auth';
import { stopAppListeners } from '@/lib/realtime';
import {
  MEXICAN_ZONES,
  MEXICAN_STATES,
  EQUIPMENT_TYPES,
  type EquipmentType,
} from '@/lib/models';
import InfoRow from '@/components/InfoRow.vue';

const auth = useAuthStore();
const router = useRouter();
const msg = ref('');
const user = computed(() => auth.currentUser);
const isCarrier = computed(
  () =>
    user.value?.role === 'carrier' || user.value?.role === 'independent_operator',
);

const routeForm = reactive({ origin: 'N.L.', destination: 'CDMX', bidirectional: true });

async function patchUser(fields: Record<string, unknown>) {
  const uid = fbAuth.currentUser?.uid;
  if (!uid) return;
  await updateDoc(doc(db, 'users', uid), fields);
  if (auth.currentUser) {
    Object.assign(auth.currentUser, fields);
  }
  msg.value = 'Perfil actualizado';
}

async function addRoute() {
  if (!user.value) return;
  const routes = [
    ...user.value.routes,
    {
      id: crypto.randomUUID(),
      originState: routeForm.origin,
      destinationState: routeForm.destination,
      bidirectional: routeForm.bidirectional,
      equipmentTypes: [] as EquipmentType[],
    },
  ];
  await patchUser({ routes });
  user.value.routes = routes;
}

async function removeRoute(id: string) {
  if (!user.value) return;
  const routes = user.value.routes.filter((r) => r.id !== id);
  await patchUser({ routes });
  user.value.routes = routes;
}

function toggleState(state: string) {
  if (!user.value) return;
  const set = new Set(user.value.coverageStates);
  if (set.has(state)) set.delete(state);
  else set.add(state);
  const coverageStates = [...set];
  void patchUser({ coverageStates });
  user.value.coverageStates = coverageStates;
}

function toggleEquipment(e: EquipmentType) {
  if (!user.value) return;
  const set = new Set(user.value.coverageEquipmentTypes);
  if (set.has(e)) set.delete(e);
  else set.add(e);
  const coverageEquipmentTypes = [...set];
  void patchUser({ coverageEquipmentTypes });
  user.value.coverageEquipmentTypes = coverageEquipmentTypes;
}

async function logout() {
  stopAppListeners();
  await auth.logout();
  await router.push({ name: 'login' });
}
</script>

<template>
  <div v-if="user" class="mx-auto w-full max-w-2xl px-4 py-6 sm:px-6">
    <h1 class="text-2xl font-bold text-navy">Perfil</h1>
    <p v-if="msg" class="mt-2 text-sm text-success">{{ msg }}</p>

    <dl class="mt-5 rounded-2xl border border-line bg-card p-4">
      <InfoRow label="Nombre" :value="user.name" />
      <InfoRow label="Email" :value="user.email" />
      <InfoRow label="Teléfono" :value="user.phone" />
      <InfoRow label="Rol" :value="user.role" />
      <InfoRow label="Status" :value="user.status" />
    </dl>

    <template v-if="isCarrier">
      <section class="mt-6">
        <h2 class="mb-2 text-sm font-semibold uppercase text-muted">Rutas</h2>
        <ul class="space-y-2">
          <li
            v-for="r in user.routes"
            :key="r.id"
            class="flex items-center justify-between rounded-xl border border-line px-3 py-2 text-sm"
          >
            <span
              >{{ r.originState }} {{ r.bidirectional ? '↔' : '→' }}
              {{ r.destinationState }}</span
            >
            <button type="button" class="text-xs text-danger" @click="removeRoute(r.id)">
              Quitar
            </button>
          </li>
        </ul>
        <div class="mt-3 grid gap-2 sm:grid-cols-3">
          <select v-model="routeForm.origin" class="cc-field !py-2 text-sm">
            <option v-for="s in MEXICAN_STATES" :key="s" :value="s">{{ s }}</option>
          </select>
          <select v-model="routeForm.destination" class="cc-field !py-2 text-sm">
            <option v-for="s in MEXICAN_STATES" :key="'d' + s" :value="s">{{ s }}</option>
          </select>
          <button type="button" class="cc-btn !h-11 text-sm" @click="addRoute">Agregar</button>
        </div>
      </section>

      <section class="mt-6">
        <h2 class="mb-2 text-sm font-semibold uppercase text-muted">Estados de cobertura</h2>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="z in MEXICAN_ZONES"
            :key="z.id"
            type="button"
            class="rounded-lg border px-2 py-1 text-xs"
            :class="
              z.states.some((s) => user!.coverageStates.includes(s))
                ? 'border-blue bg-blue-soft'
                : 'border-line'
            "
            @click="z.states.forEach((s) => toggleState(s))"
          >
            {{ z.id }}
          </button>
        </div>
      </section>

      <section class="mt-6">
        <h2 class="mb-2 text-sm font-semibold uppercase text-muted">Equipo</h2>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="e in EQUIPMENT_TYPES"
            :key="e"
            type="button"
            class="rounded-lg border px-2 py-1 text-xs"
            :class="
              user!.coverageEquipmentTypes.includes(e)
                ? 'border-blue bg-blue-soft'
                : 'border-line'
            "
            @click="toggleEquipment(e)"
          >
            {{ e }}
          </button>
        </div>
      </section>

      <label
        v-if="user!.role === 'carrier'"
        class="mt-6 flex items-center gap-2 text-sm"
      >
        <input
          type="checkbox"
          :checked="user!.handlesLTL"
          @change="
            patchUser({
              handlesLTL: ($event.target as HTMLInputElement).checked,
            })
          "
        />
        Maneja LTL
      </label>
    </template>

    <button type="button" class="cc-btn-secondary mt-8" @click="logout">
      Cerrar sesión
    </button>
  </div>
</template>
