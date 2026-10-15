<script setup lang="ts">
import { computed, ref } from 'vue';
import { RouterLink } from 'vue-router';
import StatusBadge from '@/components/StatusBadge.vue';
import EmptyState from '@/components/EmptyState.vue';
import { useDataStore } from '@/stores/data';
import type { UserStatus } from '@/lib/models';

const store = useDataStore();
const filter = ref<'' | UserStatus>('');

const list = computed(() =>
  store.users
    .filter((u) => u.role === 'carrier' || u.role === 'independent_operator')
    .filter((c) => !filter.value || c.status === filter.value),
);

const statusLabel: Record<string, string> = {
  pending_approval: 'Pendiente',
  approved: 'Aprobado',
  rejected: 'Rechazado',
  suspended: 'Suspendido',
};
</script>

<template>
  <div class="mx-auto w-full max-w-5xl px-4 py-6 sm:px-6">
    <div class="flex items-end justify-between gap-3">
      <div>
        <h1 class="text-2xl font-bold text-navy">Transportistas</h1>
        <p class="mt-1 text-sm text-muted">{{ list.length }} en directorio</p>
      </div>
      <RouterLink :to="{ name: 'admin-invitations' }" class="text-sm font-semibold text-blue">
        Invitaciones
      </RouterLink>
    </div>

    <div class="mt-4 flex flex-wrap gap-2">
      <button
        v-for="opt in [
          { v: '', l: 'Todos' },
          { v: 'pending_approval', l: 'Pendiente' },
          { v: 'approved', l: 'Aprobado' },
          { v: 'rejected', l: 'Rechazado' },
          { v: 'suspended', l: 'Suspendido' },
        ]"
        :key="opt.v"
        type="button"
        class="rounded-lg border px-3 py-1.5 text-xs font-medium"
        :class="filter === opt.v ? 'border-blue bg-blue-soft text-blue-ink' : 'border-line'"
        @click="filter = opt.v as typeof filter"
      >
        {{ opt.l }}
      </button>
    </div>

    <div class="mt-5 space-y-3">
      <div
        v-for="c in list"
        :key="c.uuid"
        class="rounded-2xl border border-line bg-card p-4"
      >
        <div class="flex items-start justify-between gap-3">
          <div>
            <RouterLink
              :to="`/admin/carriers/${c.uuid}`"
              class="font-semibold text-navy hover:text-blue"
            >
              {{ c.name }}
            </RouterLink>
            <p class="text-xs text-muted">
              {{ c.role === 'carrier' ? 'Línea' : 'Operador' }} · {{ c.phone }}
            </p>
          </div>
          <StatusBadge :status="statusLabel[c.status] || c.status" />
        </div>
        <div class="mt-3 flex flex-wrap gap-2">
          <button
            v-if="c.status !== 'approved'"
            type="button"
            class="rounded-lg bg-success px-3 py-1.5 text-xs font-semibold text-white"
            @click="store.approveCarrier(c.uuid)"
          >
            Aprobar
          </button>
          <button
            v-if="c.status !== 'rejected'"
            type="button"
            class="rounded-lg border border-line px-3 py-1.5 text-xs font-semibold"
            @click="store.rejectCarrier(c.uuid)"
          >
            Rechazar
          </button>
        </div>
      </div>
      <EmptyState v-if="!list.length" title="Sin transportistas" subtitle="Cambia el filtro." />
    </div>
  </div>
</template>
