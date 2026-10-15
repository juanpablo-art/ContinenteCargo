<script setup lang="ts">
import { computed, ref } from 'vue';
import { Users } from '@lucide/vue';
import { useDataStore } from '@/stores/data';
import EmptyState from '@/components/EmptyState.vue';
import type { UserStatus } from '@/lib/models';

const store = useDataStore();
const filter = ref<'pending' | 'approved' | 'all'>('pending');
const search = ref('');
const busyId = ref<string | null>(null);

const carriers = computed(() => {
  let list = store.users.filter((u) => u.role !== 'admin');
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
  return list.sort((a, b) => a.name.localeCompare(b.name, 'es'));
});

function statusLabel(s: UserStatus) {
  switch (s) {
    case 'pending_approval':
      return 'Pendiente';
    case 'approved':
      return 'Aprobado';
    case 'rejected':
      return 'Rechazado';
    case 'suspended':
      return 'Suspendido';
    default:
      return s;
  }
}

function statusClass(s: UserStatus) {
  switch (s) {
    case 'pending_approval':
      return 'bg-orange-soft text-orange';
    case 'approved':
      return 'bg-success-soft text-success';
    case 'rejected':
    case 'suspended':
      return 'bg-danger-soft text-danger';
    default:
      return 'bg-blue-soft text-muted';
  }
}

async function approve(id: string) {
  busyId.value = id;
  try {
    await store.approveCarrier(id);
  } finally {
    busyId.value = null;
  }
}

async function reject(id: string) {
  busyId.value = id;
  try {
    await store.rejectCarrier(id);
  } finally {
    busyId.value = null;
  }
}
</script>

<template>
  <div class="mx-auto max-w-5xl px-4 py-5 md:px-6">
    <h1 class="mb-1 text-xl font-bold text-navy">Transportistas</h1>
    <p class="mb-4 text-sm text-muted">Directorio y aprobaciones de registro</p>

    <div class="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center">
      <input
        v-model="search"
        class="cc-field py-2.5 sm:max-w-xs"
        placeholder="Buscar por nombre, correo o teléfono…"
      />
      <div class="flex gap-2">
        <button
          v-for="chip in [
            { id: 'pending' as const, label: 'Pendientes' },
            { id: 'approved' as const, label: 'Aprobados' },
            { id: 'all' as const, label: 'Todos' },
          ]"
          :key="chip.id"
          type="button"
          class="rounded-full px-3 py-1.5 text-xs font-medium"
          :class="
            filter === chip.id
              ? 'bg-brand text-white'
              : 'border border-line bg-card text-muted'
          "
          @click="filter = chip.id"
        >
          {{ chip.label }}
        </button>
      </div>
    </div>

    <EmptyState
      v-if="!carriers.length"
      title="Sin transportistas"
      subtitle="No hay registros que coincidan con este filtro."
    >
      <template #icon><Users class="size-6" /></template>
    </EmptyState>

    <div v-else class="space-y-3">
      <article
        v-for="user in carriers"
        :key="user.uuid"
        class="rounded-2xl border border-line bg-card p-4"
      >
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2">
              <h2 class="font-semibold text-navy">{{ user.name }}</h2>
              <span
                class="rounded-full px-2 py-0.5 text-[11px] font-semibold"
                :class="statusClass(user.status)"
              >
                {{ statusLabel(user.status) }}
              </span>
            </div>
            <p class="mt-1 text-sm text-muted">
              {{ user.email }} · {{ user.phone }}
            </p>
            <p class="mt-0.5 text-xs text-muted">
              {{ user.role === 'carrier' ? 'Línea transportista' : 'Operador independiente' }}
              <span v-if="user.handlesLTL"> · LTL</span>
              <span v-if="user.routes.length">
                · {{ user.routes.length }} rutas
              </span>
              <span v-else-if="user.coverageStates.length">
                · {{ user.coverageStates.length }} estados
              </span>
            </p>
          </div>
          <div v-if="user.status === 'pending_approval'" class="flex gap-2">
            <button
              type="button"
              class="rounded-lg bg-success px-3 py-1.5 text-xs font-semibold text-white disabled:opacity-50"
              :disabled="busyId === user.uuid"
              @click="approve(user.uuid)"
            >
              Aprobar
            </button>
            <button
              type="button"
              class="rounded-lg border border-line px-3 py-1.5 text-xs font-semibold text-danger disabled:opacity-50"
              :disabled="busyId === user.uuid"
              @click="reject(user.uuid)"
            >
              Rechazar
            </button>
          </div>
        </div>
      </article>
    </div>
  </div>
</template>
