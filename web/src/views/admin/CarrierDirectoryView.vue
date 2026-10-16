<script setup lang="ts">
import { computed, ref } from 'vue';
import { Users, Search, Check, X, ChevronRight, MailPlus, KeyRound, Boxes } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import EmptyState from '@/components/EmptyState.vue';
import PageHeader from '@/components/PageHeader.vue';
import StatusBadge from '@/components/StatusBadge.vue';
import SheetModal from '@/components/SheetModal.vue';
import { initials } from '@/lib/format';
import { toast } from '@/lib/toast';
import { LTL_DIRECTORY } from '@/lib/ltl-directory';
import type { AppUser } from '@/lib/models';

type Filter = 'pending' | 'approved' | 'all';

const store = useDataStore();
const all = computed(() => store.users.filter((u) => u.role !== 'admin' && u.role !== 'pricer'));
const pendingCount = computed(() => all.value.filter((u) => u.status === 'pending_approval').length);
const filter = ref<Filter>(pendingCount.value ? 'pending' : 'all');
const search = ref('');
const busyId = ref<string | null>(null);
const showPricers = ref(false);
const showLtl = ref(false);
const pickerUser = ref<AppUser | null>(null);

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

function firstName(name: string): string {
  return name.split(' ')[0] || name;
}

function companyName(user: AppUser): string {
  if (!user.companyId) return '';
  return store.companies.find((company) => company.id === user.companyId)?.name ?? '';
}

function pricerLabel(user: AppUser): string {
  if (!user.pricerId) return 'Sin pricer';
  const pricer = store.users.find((item) => item.uuid === user.pricerId);
  return pricer ? firstName(pricer.name) : 'Sin pricer';
}

const pricerGroups = computed(() =>
  store.pricers().map((pricer) => ({
    pricer,
    carriers: store.carriersForPricer(pricer.uuid),
  })),
);

const unassignedCarriers = computed(() =>
  all.value.filter((user) => !user.pricerId).slice().sort((a, b) => a.name.localeCompare(b.name, 'es')),
);

async function assignPricer(pricerId: string | null) {
  const carrier = pickerUser.value;
  if (!carrier) return;
  try {
    await store.assignPricerToCarrier(carrier.uuid, pricerId);
    toast.success(pricerId ? 'Pricer asignado' : 'Pricer quitado');
    pickerUser.value = null;
  } catch (e) {
    toast.error('No se pudo asignar el pricer', e instanceof Error ? e.message : undefined);
  }
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
        <button type="button" class="cc-btn-secondary h-10 w-auto px-3 text-[13px]" @click="showPricers = true">
          <KeyRound class="size-4" aria-hidden="true" />
          Pricers
        </button>
        <button type="button" class="cc-btn-secondary h-10 w-auto px-3 text-[13px]" @click="showLtl = true">
          <Boxes class="size-4" aria-hidden="true" />
          LTL
        </button>
        <RouterLink :to="{ name: 'admin-directory' }" class="cc-btn-secondary h-10 w-auto px-3 text-[13px]">
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
        <div class="flex min-w-0 flex-1 items-center gap-3">
          <RouterLink
            :to="{ name: 'admin-carrier-detail', params: { id: user.uuid } }"
            class="flex size-10 shrink-0 items-center justify-center rounded-full text-[13px] font-bold"
            :class="user.role === 'carrier' ? 'bg-blue-soft text-brand' : 'bg-navy/[0.07] text-navy'"
          >
            {{ initials(user.name) }}
          </RouterLink>
          <div class="min-w-0 flex-1">
            <RouterLink
              :to="{ name: 'admin-carrier-detail', params: { id: user.uuid } }"
              class="block min-w-0"
            >
              <div class="flex items-center gap-2">
                <p class="truncate text-sm font-semibold text-navy">{{ user.name }}</p>
                <span v-if="user.handlesLTL" class="cc-badge bg-teal-50 px-2 text-teal-700">LTL</span>
              </div>
              <p class="mt-0.5 truncate text-xs text-muted">
                {{ user.role === 'carrier' ? 'Línea transportista' : 'Operador independiente' }}
                <template v-if="companyName(user)"> · {{ companyName(user) }}</template>
                · {{ coverageLabel(user) }} · {{ user.email }}
              </p>
            </RouterLink>
            <button
              type="button"
              class="mt-1.5 inline-flex items-center gap-1 rounded-full bg-blue-soft px-2 py-0.5 text-[11px] font-semibold text-brand"
              @click="pickerUser = user"
            >
              <KeyRound class="size-3" aria-hidden="true" />
              {{ pricerLabel(user) }}
            </button>
          </div>
        </div>
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

    <SheetModal
      :open="Boolean(pickerUser)"
      :title="pickerUser ? `Asignar pricer a ${firstName(pickerUser.name)}` : 'Asignar pricer'"
      @close="pickerUser = null"
    >
      <button
        type="button"
        class="mb-2 flex w-full items-center justify-between rounded-xl px-3 py-3 text-left text-sm text-muted hover:bg-background"
        @click="assignPricer(null)"
      >
        Sin pricer asignado
        <Check v-if="pickerUser && !pickerUser.pricerId" class="size-4 text-brand" aria-hidden="true" />
      </button>
      <p class="mb-2 mt-3 text-xs font-semibold uppercase tracking-wide text-muted">Pricers disponibles</p>
      <p v-if="!store.pricers().length" class="text-sm text-muted">No hay pricers registrados.</p>
      <button
        v-for="pricer in store.pricers()"
        :key="pricer.uuid"
        type="button"
        class="flex w-full items-center justify-between gap-3 rounded-xl px-3 py-3 text-left hover:bg-background"
        @click="assignPricer(pricer.uuid)"
      >
        <span>
          <span class="block text-sm font-semibold text-navy">{{ pricer.name }}</span>
          <span class="block text-xs text-muted">{{ pricer.email }}</span>
        </span>
        <Check
          v-if="pickerUser?.pricerId === pricer.uuid"
          class="size-4 shrink-0 text-brand"
          aria-hidden="true"
        />
      </button>
    </SheetModal>

    <SheetModal :open="showPricers" title="Directorio Pricers" @close="showPricers = false">
      <p v-if="!pricerGroups.length" class="text-sm text-muted">No hay pricers registrados en el sistema.</p>
      <section v-for="group in pricerGroups" :key="group.pricer.uuid" class="mb-5">
        <div class="mb-2 flex items-center gap-2">
          <KeyRound class="size-4 text-brand" aria-hidden="true" />
          <div class="min-w-0 flex-1">
            <p class="text-sm font-semibold text-navy">{{ group.pricer.name }}</p>
            <p class="truncate text-xs text-muted">{{ group.pricer.email }}</p>
          </div>
          <span class="cc-badge bg-blue-soft text-brand">{{ group.carriers.length }}</span>
        </div>
        <p v-if="!group.carriers.length" class="text-sm italic text-muted">Sin transportistas asignados</p>
        <div v-else class="divide-y divide-line rounded-xl border border-line">
          <div v-for="carrier in group.carriers" :key="carrier.uuid" class="flex items-center gap-3 px-3 py-2.5">
            <div class="min-w-0 flex-1">
              <p class="truncate text-sm font-semibold text-navy">{{ carrier.name }}</p>
              <p class="truncate text-xs text-muted">{{ companyName(carrier) || 'Sin empresa' }}</p>
            </div>
            <div class="text-right">
              <p class="text-xs text-muted">{{ carrier.phone }}</p>
              <StatusBadge :status="carrier.status" />
            </div>
          </div>
        </div>
      </section>
      <section v-if="unassignedCarriers.length">
        <div class="mb-2 flex items-center gap-2">
          <p class="flex-1 text-sm font-semibold text-navy">Sin pricer asignado</p>
          <span class="cc-badge bg-background text-muted">{{ unassignedCarriers.length }}</span>
        </div>
        <div class="divide-y divide-line rounded-xl border border-line">
          <div v-for="carrier in unassignedCarriers" :key="carrier.uuid" class="px-3 py-2.5">
            <p class="text-sm font-semibold text-navy">{{ carrier.name }}</p>
            <p class="text-xs text-muted">{{ carrier.phone }}</p>
          </div>
        </div>
      </section>
    </SheetModal>

    <SheetModal :open="showLtl" title="Directorio LTL" @close="showLtl = false">
      <p class="mb-4 rounded-xl bg-background px-3 py-2 text-xs text-muted">
        Solo No Hazmat salvo Quick Express (tiene habilitación Hazmat).
      </p>
      <div class="space-y-3">
        <article v-for="carrier in LTL_DIRECTORY" :key="carrier.name" class="rounded-xl border border-line px-3 py-3">
          <div class="flex items-center gap-2">
            <p class="text-sm font-semibold text-navy">{{ carrier.name }}</p>
            <span v-if="carrier.handlesHazmat" class="cc-badge bg-danger-soft text-danger">Hazmat</span>
          </div>
          <div class="mt-2 flex flex-wrap gap-1">
            <span
              v-for="service in carrier.services"
              :key="service"
              class="rounded-full bg-blue-soft px-2 py-0.5 text-[11px] font-medium text-brand"
            >
              {{ service }}
            </span>
          </div>
          <p class="mt-2 text-xs text-muted">{{ carrier.contact }}</p>
        </article>
      </div>
    </SheetModal>
  </div>
</template>
