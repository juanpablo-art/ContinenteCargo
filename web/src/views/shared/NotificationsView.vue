<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { Bell } from '@lucide/vue';
import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';
import EmptyState from '@/components/EmptyState.vue';
import { formatDate } from '@/lib/format';

const auth = useAuthStore();
const store = useDataStore();
const router = useRouter();

const items = computed(() => {
  const uid = auth.currentUser?.uuid;
  if (!uid) return [];
  return store.notifications
    .filter((n) => n.userId === uid)
    .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
});

async function open(id: string, loadId?: string) {
  await store.markNotificationRead(id);
  if (loadId) {
    const role = auth.currentUser?.role;
    if (role === 'admin') {
      void router.push({ name: 'admin-load-detail', params: { id: loadId } });
    } else {
      const isTrip = store.myTrips().some((t) => t.id === loadId);
      void router.push({
        name: isTrip ? 'carrier-trip-detail' : 'carrier-load-detail',
        params: { id: loadId },
      });
    }
  }
}

async function markAll() {
  await store.markAllRead();
}
</script>

<template>
  <div class="cc-page-narrow">
    <div class="mb-4 flex items-center justify-between gap-3">
      <h1 class="cc-h1">Avisos</h1>
      <button
        v-if="items.some((n) => !n.isRead)"
        type="button"
        class="text-sm font-medium text-brand"
        @click="markAll"
      >
        Marcar todo leído
      </button>
    </div>

    <EmptyState
      v-if="!items.length"
      title="Sin avisos"
      subtitle="Cuando haya novedades de cargas u ofertas, aparecerán aquí."
    >
      <template #icon><Bell class="size-6" /></template>
    </EmptyState>

    <div v-else class="space-y-2">
      <button
        v-for="n in items"
        :key="n.id"
        type="button"
        class="w-full rounded-2xl border px-4 py-3 text-left transition"
        :class="
          n.isRead
            ? 'border-line bg-card opacity-75'
            : 'border-blue/25 bg-blue-soft/40'
        "
        @click="open(n.id, n.loadId)"
      >
        <div class="flex items-start justify-between gap-3">
          <div class="min-w-0">
            <p class="text-sm font-semibold text-navy">{{ n.title }}</p>
            <p class="mt-0.5 text-sm text-muted">{{ n.body }}</p>
            <p class="mt-1 text-[11px] text-muted">{{ formatDate(n.createdAt) }}</p>
          </div>
          <span
            v-if="!n.isRead"
            class="mt-1 size-2 shrink-0 rounded-full bg-orange"
            aria-hidden="true"
          />
        </div>
      </button>
    </div>
  </div>
</template>
