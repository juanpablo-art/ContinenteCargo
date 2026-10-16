<script setup lang="ts">
import { computed, ref } from 'vue';
import { Users, Search, Check, X, ChevronRight, MailPlus } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import EmptyState from '@/components/EmptyState.vue';
import PageHeader from '@/components/PageHeader.vue';
import StatusBadge from '@/components/StatusBadge.vue';
import { initials } from '@/lib/format';
import { toast } from '@/lib/toast';

type Filter = 'pending' | 'approved' | 'all';

const store = useDataStore();
const all = computed(() => store.users.filter((u) => u.role !== 'admin'));
const pendingCount = computed(() => all.value.filter((u) => u.status === 'pending_approval').length);
const filter = ref<Filter>(pendingCount.value ? 'pending' : 'all');
const search = ref('');
const busyId = ref<string | null>(null);

const carriers = computed(() => {
  let list = all.value;
  if (filter.value === 'pending') {
    list = list.filter((u) => u.status === 'pending_approval');
  } else if (filter.value === 'approved') {
    list = list.filter((u) => u.status === 'approved');
  }
  const q = search.value.trim().toLowerCase();
  if (q) {
    list = list.filter(
      (u) =>
        u.name.toLowerCase().includes(q) ||
        u.email.toLowerCase().includes(q) ||
        u.phone.includes(q),
    );
  }
  return list.slice().sort((a, b) => a.name.localeCompare(b.name, 'es'));
});

const chips = computed(() => [
  { id: 'pending' as const, label: 'Pendientes', n: pendingCount.value },
  { id: 'approved' as const, label: 'Aprobados', n: all.value.filter((u) => u.status === 'approved').length },
  { id: 'all' as const, label: 'Todos', n: all.value.length },
]);

function coverageLabel(u: (typeof all.value)[number]) {
  if (u.routes.length) return `${u.routes.length} ${u.routes.length === 1 ? 'ruta' : 'rutas'}`;
  if (u.coverageStates.length) return `${u.coverageStates.length} estados`;
  if (u.coverageZones.length) return u.coverageZones.join(', ');
  return 'Cobertura nacional';
}

async function act(id: string, approve: boolean, name: string) {
  busyId.value = id;
  try {
    if (approve) await store.approveCarrier(id);
    else await store.rejectCarrier(id);
    toast.success(approve ? `${name} aprobado` : `${name} rechazado`);
  } catch (e) {
    toast.error('No se pudo actualizar', e instanceof Error ? e.message : undefined);
  } finally {
    busyId.value = null;
  }
}
</script>

<template>
  <div class="cc-page">
    <PageHeader title="Transportistas" subtitle="Directorio y aprobaciones de registro">
      <template #actions>
        <RouterLink :to="{ name: 'admin-directory' }" class="cc-btn-secondary w-auto px-4">
          <MailPlus class="size-4" aria-hidden="true" />
          Directorio
        </RouterLink>
      </template>
    </PageHeader>

    <div class="mb-5 flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
      <div class="cc-scroll-x">
        <button
          v-for="chip in chips"
          :key="chip.id"
          type="button"
          class="cc-chip"
          :class="filter === chip.id && 'cc-chip-active'"
          @click="filter = chip.id"
        >
          {{ chip.label }}
          <span
            class="rounded-full px-1.5 text-[11px] font-semibold tabular-nums"
            :class="
              filter === chip.id
                ? 'bg-white/20'
                : chip.id === 'pending' && chip.n
                  ? 'bg-orange text-white'
                  : 'bg-background text-muted'
            "
          >
            {{ chip.n }}
          </span>
        </button>
      </div>
      <label class="relative block md:w-80">
        <Search class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted" />
        <input
          v-model="search"
          type="search"
          class="cc-field pl-10"
          placeholder="Buscar por nombre, correo o teléfono"
        />
      </label>
    </div>

    <div v-if="!carriers.length" class="cc-card">
      <EmptyState
        :title="filter === 'pending' ? 'Sin solicitudes pendientes' : 'Sin transportistas'"
        :subtitle="filter === 'pending' ? 'Todas las solicitudes de registro están atendidas.' : 'No hay registros que coincidan.'"
      >
        <template #icon><Users /></template>
      </EmptyState>
    </div>

    <div v-else class="cc-card divide-y divide-line overflow-hidden">
      <div
        v-for="user in carriers"
        :key="user.uuid"
        class="flex flex-wrap items-center gap-3 px-4 py-3.5 transition hover:bg-background/60 sm:flex-nowrap md:px-5"
      >
        <RouterLink
          :to="{ name: 'admin-carrier-detail', params: { id: user.uuid } }"
          class="flex min-w-0 flex-1 items-center gap-3"
        >
          <span
            class="flex size-10 shrink-0 items-center justify-center rounded-full text-[13px] font-bold"
            :class="user.role === 'carrier' ? 'bg-blue-soft text-brand' : 'bg-navy/[0.07] text-navy'"
          >
            {{ initials(user.name) }}
          </span>
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2">
              <p class="truncate text-sm font-semibold text-navy">{{ user.name }}</p>
              <span v-if="user.handlesLTL" class="cc-badge bg-teal-50 px-2 text-teal-700">LTL</span>
            </div>
            <p class="mt-0.5 truncate text-xs text-muted">
              {{ user.role === 'carrier' ? 'Línea transportista' : 'Operador independiente' }}
              · {{ coverageLabel(user) }} · {{ user.email }}
            </p>
          </div>
        </RouterLink>
        <div class="flex shrink-0 items-center gap-2">
          <template v-if="user.status === 'pending_approval'">
            <button
              type="button"
              class="cc-btn-secondary h-9 w-auto px-3 text-[13px] text-danger"
              :disabled="busyId === user.uuid"
              @click="act(user.uuid, false, user.name)"
            >
              <X class="size-4" aria-hidden="true" /> Rechazar
            </button>
            <button
              type="button"
              class="cc-btn-success h-9 w-auto px-3 text-[13px]"
              :disabled="busyId === user.uuid"
              @click="act(user.uuid, true, user.name)"
            >
              <Check class="size-4" aria-hidden="true" /> Aprobar
            </button>
          </template>
          <template v-else>
            <StatusBadge :status="user.status" />
            <ChevronRight class="hidden size-4 text-muted sm:block" aria-hidden="true" />
          </template>
        </div>
      </div>
    </div>
  </div>
</template>
