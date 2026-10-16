<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { Mail, Phone, ShieldCheck, LogOut, Plus, X, ArrowRight, ArrowLeftRight, Boxes, Settings } from '@lucide/vue';
import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';
import {
  EQUIPMENT_TYPES,
  MEXICAN_STATES,
  newUuid,
  type CarrierRoute,
  type EquipmentType,
} from '@/lib/models';
import { initials } from '@/lib/format';
import { toast } from '@/lib/toast';
import StatusBadge from '@/components/StatusBadge.vue';

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
const dirty = ref(false);

const newOrigin = ref('N.L.');
const newDest = ref('CDMX');
const newBidirectional = ref(true);
const newEquipment = ref<EquipmentType[]>([]);

const profileName = ref('');
const profilePhone = ref('');
const savingProfile = ref(false);

watch(
  user,
  (next) => {
    if (!next || savingProfile.value) return;
    profileName.value = next.name;
    profilePhone.value = next.phone;
  },
  { immediate: true },
);

const profileDirty = computed(
  () =>
    profileName.value.trim() !== (user.value?.name ?? '') ||
    profilePhone.value.trim() !== (user.value?.phone ?? ''),
);

async function saveProfile() {
  savingProfile.value = true;
  try {
    await store.updateOwnProfile(profileName.value, profilePhone.value);
    toast.success('Perfil actualizado', 'Tus datos de contacto quedaron guardados.');
  } catch (err) {
    toast.error('No se pudo guardar el perfil', err instanceof Error ? err.message : undefined);
  } finally {
    savingProfile.value = false;
  }
}

const roleLabel = computed(() => {
  switch (user.value?.role) {
    case 'admin':
      return 'Administrador';
    case 'carrier':
      return 'Línea transportista';
    case 'independent_operator':
      return 'Operador independiente';
    case 'pricer':
      return 'Pricer – Continente Cargo';
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
  dirty.value = true;
}

function removeRoute(id: string) {
  routes.value = routes.value.filter((r) => r.id !== id);
  dirty.value = true;
}

async function saveRoutes() {
  saving.value = true;
  try {
    await store.updateCarrierRoutes(routes.value);
    dirty.value = false;
    toast.success('Rutas actualizadas', 'Recibirás avisos de cargas en estas rutas.');
  } catch (err) {
    toast.error(
      'No se pudieron guardar las rutas',
      err instanceof Error ? err.message : undefined,
    );
  } finally {
    saving.value = false;
  }
}

async function toggleLTL() {
  handlesLTL.value = !handlesLTL.value;
  try {
    await store.setHandlesLTL(handlesLTL.value);
    toast.success(handlesLTL.value ? 'Cargas LTL activadas' : 'Cargas LTL desactivadas');
  } catch (e) {
    handlesLTL.value = !handlesLTL.value;
    toast.error('No se pudo actualizar', e instanceof Error ? e.message : undefined);
  }
}

async function logout() {
  const { stopAppListeners } = await import('@/lib/realtime');
  stopAppListeners();
  await auth.logout();
  await router.push({ name: 'login' });
}
</script>

<template>
  <div v-if="user" class="cc-page-narrow space-y-5">
    <section class="cc-card overflow-hidden">
      <div class="h-20 bg-gradient-to-r from-navy-deep via-navy to-blue md:h-24" aria-hidden="true" />
      <div class="px-5 pb-5">
        <div class="-mt-9 flex items-end justify-between gap-3">
          <span
            class="flex size-[72px] items-center justify-center rounded-2xl bg-gradient-to-br from-blue to-navy-soft text-2xl font-bold text-white shadow-elevated ring-4 ring-card"
          >
            {{ initials(user.name) }}
          </span>
          <StatusBadge :status="user.status" />
        </div>
        <h1 class="cc-h1 mt-3">{{ user.name }}</h1>
        <p class="text-sm text-muted">{{ roleLabel }}</p>

        <dl class="mt-5 grid gap-2 sm:grid-cols-2">
          <div class="flex items-center gap-3 rounded-xl bg-background px-3.5 py-3">
            <Mail class="size-4 shrink-0 text-muted" aria-hidden="true" />
            <div class="min-w-0">
              <dt class="text-[11px] font-medium text-muted">Correo</dt>
              <dd class="truncate text-sm font-medium text-navy">{{ user.email }}</dd>
            </div>
          </div>
          <div class="flex items-center gap-3 rounded-xl bg-background px-3.5 py-3">
            <Phone class="size-4 shrink-0 text-muted" aria-hidden="true" />
            <div class="min-w-0">
              <dt class="text-[11px] font-medium text-muted">Teléfono</dt>
              <dd class="truncate text-sm font-medium text-navy">{{ user.phone || '—' }}</dd>
            </div>
          </div>
        </dl>
      </div>
    </section>

    <section v-if="user.role === 'pricer'" class="cc-card p-5">
      <div class="flex items-start gap-4">
        <span class="cc-icon-tile"><Settings class="size-[18px]" aria-hidden="true" /></span>
        <div class="min-w-0">
          <h2 class="cc-h2">Configuración</h2>
          <p class="mt-0.5 text-[13px] text-muted">
            Edita tu nombre y teléfono cuando haga falta. El correo es el de tu acceso y el de las invitaciones.
          </p>
        </div>
      </div>

      <form class="mt-5 space-y-4" @submit.prevent="saveProfile">
        <div>
          <label class="cc-label" for="profile-name">Nombre</label>
          <input
            id="profile-name"
            v-model="profileName"
            type="text"
            autocomplete="name"
            maxlength="80"
            required
            class="cc-field"
          />
        </div>
        <div>
          <label class="cc-label" for="profile-phone">Teléfono</label>
          <input
            id="profile-phone"
            v-model="profilePhone"
            type="tel"
            autocomplete="tel"
            maxlength="30"
            class="cc-field"
          />
        </div>
        <div>
          <label class="cc-label" for="profile-email">Correo</label>
          <input
            id="profile-email"
            :value="user.email"
            type="email"
            autocomplete="email"
            disabled
            class="cc-field disabled:bg-background disabled:text-muted"
          />
          <p class="cc-hint">Este correo no se cambia desde aquí.</p>
        </div>
        <button type="submit" class="cc-btn w-full sm:w-auto" :disabled="savingProfile || !profileDirty">
          {{ savingProfile ? 'Guardando…' : 'Guardar perfil' }}
        </button>
      </form>
    </section>

    <section v-if="user.role === 'carrier'" class="cc-card flex items-center gap-4 p-5">
      <span class="cc-icon-tile bg-teal-50 text-teal-700"><Boxes class="size-[18px]" aria-hidden="true" /></span>
      <div class="min-w-0 flex-1">
        <h2 class="cc-h2">Opero cargas consolidadas (LTL)</h2>
        <p class="mt-0.5 text-[13px] text-muted">Recibe y cotiza cargas del marketplace consolidado.</p>
      </div>
      <button
        type="button"
        role="switch"
        :aria-checked="handlesLTL"
        aria-label="Opero cargas LTL"
        class="relative h-7 w-12 shrink-0 rounded-full transition"
        :class="handlesLTL ? 'bg-brand' : 'bg-[rgb(214_222_234)]'"
        @click="toggleLTL"
      >
        <span
          class="absolute top-0.5 size-6 rounded-full bg-white shadow-md transition-all duration-200"
          :class="handlesLTL ? 'left-[22px]' : 'left-0.5'"
        />
      </button>
    </section>

    <section v-if="isCarrier" class="cc-card overflow-hidden">
      <div class="p-5">
        <h2 class="cc-h2">Mis rutas</h2>
        <p class="mt-0.5 text-[13px] text-muted">
          Solo recibirás cargas que coincidan. Al definir rutas explícitas se reemplaza la cobertura por estados o zonas.
        </p>

        <ul v-if="routes.length" class="mt-4 space-y-2">
          <li
            v-for="r in routes"
            :key="r.id"
            class="flex items-center gap-3 rounded-xl border border-line px-3.5 py-3"
          >
            <component
              :is="r.bidirectional ? ArrowLeftRight : ArrowRight"
              class="size-4 shrink-0 text-brand"
              aria-hidden="true"
            />
            <div class="min-w-0 flex-1">
              <p class="text-sm font-semibold text-navy">
                {{ r.originState }}
                <span class="font-normal text-muted">{{ r.bidirectional ? '↔' : '→' }}</span>
                {{ r.destinationState }}
              </p>
              <p class="truncate text-xs text-muted">
                {{ r.equipmentTypes.length ? r.equipmentTypes.join(', ') : 'Cualquier equipo' }}
              </p>
            </div>
            <button
              type="button"
              class="flex size-8 shrink-0 items-center justify-center rounded-lg text-muted transition hover:bg-danger-soft hover:text-danger"
              aria-label="Quitar ruta"
              @click="removeRoute(r.id)"
            >
              <X class="size-4" />
            </button>
          </li>
        </ul>
        <p v-else class="mt-4 rounded-xl bg-background px-4 py-3 text-[13px] text-muted">
          Sin rutas explícitas: recibes cargas según tu cobertura de registro.
        </p>
      </div>

      <div class="space-y-3 border-t border-line bg-background/50 p-5">
        <p class="text-[13px] font-semibold text-navy">Agregar ruta</p>
        <div class="grid grid-cols-[1fr_auto_1fr] items-center gap-2">
          <select v-model="newOrigin" class="cc-field" aria-label="Origen">
            <option v-for="s in MEXICAN_STATES" :key="s" :value="s">{{ s }}</option>
          </select>
          <component
            :is="newBidirectional ? ArrowLeftRight : ArrowRight"
            class="size-4 text-muted"
            aria-hidden="true"
          />
          <select v-model="newDest" class="cc-field" aria-label="Destino">
            <option v-for="s in MEXICAN_STATES" :key="`d-${s}`" :value="s">{{ s }}</option>
          </select>
        </div>
        <label class="cc-check">
          <input v-model="newBidirectional" type="checkbox" />
          Ida y vuelta (bidireccional)
        </label>
        <div>
          <p class="mb-2 text-xs font-medium text-muted">Equipos (opcional)</p>
          <div class="flex flex-wrap gap-1.5">
            <button
              v-for="eq in EQUIPMENT_TYPES"
              :key="eq"
              type="button"
              class="cc-chip h-8 text-[12.5px]"
              :class="newEquipment.includes(eq) && 'cc-chip-active'"
              @click="toggleEq(eq)"
            >
              {{ eq }}
            </button>
          </div>
        </div>
        <div class="flex flex-col gap-2 pt-1 sm:flex-row">
          <button type="button" class="cc-btn-secondary sm:flex-1" @click="addRoute">
            <Plus class="size-4" aria-hidden="true" /> Agregar a la lista
          </button>
          <button type="button" class="cc-btn sm:flex-1" :disabled="saving || !dirty" @click="saveRoutes">
            {{ saving ? 'Guardando…' : 'Guardar rutas' }}
          </button>
        </div>
      </div>
    </section>

    <section v-if="user.role === 'admin'" class="cc-card flex items-center gap-4 p-5">
      <span class="cc-icon-tile"><ShieldCheck class="size-[18px]" aria-hidden="true" /></span>
      <div>
        <h2 class="cc-h2">Acceso de administrador</h2>
        <p class="mt-0.5 text-[13px] text-muted">
          Puedes publicar cargas, aprobar transportistas y ver información privada de clientes.
        </p>
      </div>
    </section>

    <button type="button" class="cc-btn-secondary text-danger hover:!border-danger/30 hover:!bg-danger-soft" @click="logout">
      <LogOut class="size-4" aria-hidden="true" />
      Cerrar sesión
    </button>
  </div>
</template>
