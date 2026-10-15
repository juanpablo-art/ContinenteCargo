<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
import { Mail, Phone, ArrowRight, ArrowLeftRight, UserX, Check, X, Truck } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import PageHeader from '@/components/PageHeader.vue';
import StatusBadge from '@/components/StatusBadge.vue';
import EmptyState from '@/components/EmptyState.vue';
import { formatDate, initials } from '@/lib/format';
import { toast } from '@/lib/toast';

const route = useRoute();
const store = useDataStore();
const busy = ref(false);

const user = computed(() => store.users.find((u) => u.uuid === String(route.params.id)));
const units = computed(() =>
  user.value
    ? store.units.filter(
        (u) =>
          (u.ownerId === user.value!.uuid || u.ownerId === user.value!.companyId) &&
          u.notes !== 'availability_post',
      )
    : [],
);
const trips = computed(() =>
  user.value
    ? store.loads.filter(
        (l) => l.assignedCarrierId === user.value!.uuid || l.confirmedCarrierIds.includes(user.value!.uuid),
      )
    : [],
);

async function act(approve: boolean) {
  if (!user.value) return;
  busy.value = true;
  try {
    if (approve) await store.approveCarrier(user.value.uuid);
    else await store.rejectCarrier(user.value.uuid);
    toast.success(approve ? 'Transportista aprobado' : 'Registro rechazado');
  } catch (e) {
    toast.error('No se pudo actualizar', e instanceof Error ? e.message : undefined);
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <div class="cc-page-narrow">
    <PageHeader
      v-if="!user"
      title="Transportista"
      :back="{ name: 'admin-carriers' }"
      back-label="Transportistas"
    />
    <div v-if="!user" class="cc-card">
      <EmptyState title="Transportista no encontrado" subtitle="Puede que la cuenta se haya eliminado.">
        <template #icon><UserX /></template>
      </EmptyState>
    </div>

    <template v-else>
      <button type="button" class="cc-back" @click="$router.push({ name: 'admin-carriers' })">
        ‹ Transportistas
      </button>

      <section class="cc-card p-5">
        <div class="flex flex-wrap items-start gap-4">
          <span
            class="flex size-14 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-blue to-navy-soft text-lg font-bold text-white shadow-brand"
          >
            {{ initials(user.name) }}
          </span>
          <div class="min-w-0 flex-1">
            <div class="flex flex-wrap items-center gap-2">
              <h1 class="cc-h1">{{ user.name }}</h1>
              <StatusBadge :status="user.status" />
            </div>
            <p class="mt-0.5 text-sm text-muted">
              {{ user.role === 'carrier' ? 'Línea transportista' : 'Operador independiente' }}
              <template v-if="user.createdAt"> · Registro {{ formatDate(user.createdAt) }}</template>
            </p>
          </div>
        </div>

        <div class="mt-5 grid gap-2 sm:grid-cols-2">
          <a :href="`mailto:${user.email}`" class="flex items-center gap-3 rounded-xl bg-background p-3 transition hover:bg-blue-soft/60">
            <Mail class="size-4 text-muted" aria-hidden="true" />
            <span class="truncate text-sm font-medium text-navy">{{ user.email }}</span>
          </a>
          <a :href="`tel:${user.phone}`" class="flex items-center gap-3 rounded-xl bg-background p-3 transition hover:bg-blue-soft/60">
            <Phone class="size-4 text-muted" aria-hidden="true" />
            <span class="truncate text-sm font-medium text-navy">{{ user.phone || '—' }}</span>
          </a>
        </div>

        <div v-if="user.status === 'pending_approval'" class="mt-5 flex gap-2 border-t border-line pt-5">
          <button type="button" class="cc-btn-secondary flex-1 text-danger" :disabled="busy" @click="act(false)">
            <X class="size-4" aria-hidden="true" /> Rechazar
          </button>
          <button type="button" class="cc-btn-success flex-1" :disabled="busy" @click="act(true)">
            <Check class="size-4" aria-hidden="true" /> Aprobar registro
          </button>
        </div>
      </section>

      <div class="mt-4 grid grid-cols-3 gap-3">
        <div class="cc-card p-4 text-center">
          <p class="text-2xl font-bold tabular-nums text-navy">{{ units.length }}</p>
          <p class="text-xs text-muted">Unidades</p>
        </div>
        <div class="cc-card p-4 text-center">
          <p class="text-2xl font-bold tabular-nums text-navy">{{ trips.length }}</p>
          <p class="text-xs text-muted">Viajes</p>
        </div>
        <div class="cc-card p-4 text-center">
          <p class="text-2xl font-bold text-navy">{{ user.handlesLTL ? 'Sí' : 'No' }}</p>
          <p class="text-xs text-muted">Opera LTL</p>
        </div>
      </div>

      <section class="cc-card mt-4 p-5">
        <h2 class="cc-h2 mb-3">Cobertura</h2>
        <div v-if="user.routes.length" class="space-y-2">
          <div
            v-for="r in user.routes"
            :key="r.id"
            class="flex items-center gap-3 rounded-xl border border-line px-3.5 py-3"
          >
            <component :is="r.bidirectional ? ArrowLeftRight : ArrowRight" class="size-4 text-brand" aria-hidden="true" />
            <div class="min-w-0">
              <p class="text-sm font-semibold text-navy">
                {{ r.originState }} {{ r.bidirectional ? '↔' : '→' }} {{ r.destinationState }}
              </p>
              <p class="truncate text-xs text-muted">
                {{ r.equipmentTypes.length ? r.equipmentTypes.join(', ') : 'Cualquier equipo' }}
              </p>
            </div>
          </div>
        </div>
        <template v-else>
          <p v-if="user.coverageZones.length" class="text-[13px] font-medium text-muted">Zonas</p>
          <div v-if="user.coverageZones.length" class="mt-1.5 flex flex-wrap gap-1.5">
            <span v-for="z in user.coverageZones" :key="z" class="cc-badge bg-blue-soft text-blue-ink">{{ z }}</span>
          </div>
          <p v-if="user.coverageStates.length" class="mt-3 text-[13px] font-medium text-muted">Estados</p>
          <div v-if="user.coverageStates.length" class="mt-1.5 flex flex-wrap gap-1.5">
            <span v-for="s in user.coverageStates" :key="s" class="cc-badge bg-background text-ink/80">{{ s }}</span>
          </div>
          <p v-if="!user.coverageZones.length && !user.coverageStates.length" class="text-sm text-muted">
            Sin restricciones de cobertura.
          </p>
        </template>
        <div v-if="user.coverageEquipmentTypes.length" class="mt-4">
          <p class="text-[13px] font-medium text-muted">Equipos</p>
          <div class="mt-1.5 flex flex-wrap gap-1.5">
            <span v-for="e in user.coverageEquipmentTypes" :key="e" class="cc-badge bg-background text-ink/80">{{ e }}</span>
          </div>
        </div>
      </section>

      <section v-if="units.length" class="cc-card mt-4 overflow-hidden">
        <h2 class="cc-h2 px-5 pb-3 pt-5">Flota</h2>
        <ul class="divide-y divide-line border-t border-line">
          <li v-for="u in units" :key="u.id" class="flex items-center gap-3 px-5 py-3">
            <span class="cc-icon-tile size-9"><Truck class="size-4" aria-hidden="true" /></span>
            <div class="min-w-0 flex-1">
              <p class="font-mono text-sm font-semibold text-navy">{{ u.plates || 'Sin placas' }}</p>
              <p class="truncate text-xs text-muted">{{ u.equipmentType }} · {{ u.currentLocation }}</p>
            </div>
            <StatusBadge :status="u.status" />
          </li>
        </ul>
      </section>
    </template>
  </div>
</template>
