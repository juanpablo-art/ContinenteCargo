<script setup lang="ts">
import { computed } from 'vue';
import { useDataStore } from '@/stores/data';
import { formatDateTime } from '@/lib/format';
import type { NotificationType } from '@/lib/models';
import EmptyState from '@/components/EmptyState.vue';

const store = useDataStore();

const icons: Record<NotificationType, string> = {
  new_load: '📦',
  load_assigned: '✅',
  outbid: '⬆',
  load_cancelled: '❌',
  status_changed: '🔄',
  registration_approved: '👤',
  registration_rejected: '⛔',
  auction_closing_soon: '⏰',
};

const sorted = computed(() =>
  [...store.notifications].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime()),
);
</script>

<template>
  <div class="mx-auto w-full max-w-2xl px-4 py-6 sm:px-6">
    <div class="flex items-end justify-between">
      <h1 class="text-2xl font-bold text-navy">Avisos</h1>
      <button
        v-if="store.unreadCount"
        type="button"
        class="text-sm font-semibold text-blue"
        @click="store.markAllRead()"
      >
        Marcar todas leídas
      </button>
    </div>
    <ul class="mt-5 space-y-2">
      <li
        v-for="n in sorted"
        :key="n.id"
        class="cursor-pointer rounded-2xl border border-line bg-card p-4"
        :class="n.isRead ? 'opacity-70' : 'ring-1 ring-blue/20'"
        @click="store.markNotificationRead(n.id)"
      >
        <div class="flex gap-3">
          <span class="text-xl" aria-hidden="true">{{ icons[n.type] || '🔔' }}</span>
          <div class="min-w-0">
            <p class="text-sm font-semibold text-navy">{{ n.title }}</p>
            <p class="mt-0.5 text-sm text-muted">{{ n.body }}</p>
            <p class="mt-1 text-xs text-muted">{{ formatDateTime(n.createdAt) }}</p>
          </div>
        </div>
      </li>
    </ul>
    <EmptyState
      v-if="!sorted.length"
      title="Sin notificaciones"
      subtitle="Cuando haya actividad aparecerá aquí."
    />
  </div>
</template>
