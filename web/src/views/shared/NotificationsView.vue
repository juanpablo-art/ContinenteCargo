<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import {
  Bell,
  BellOff,
  CheckCheck,
  Package,
  TrendingDown,
  Timer,
  CircleCheck,
  CircleX,
  Activity,
  UserCheck,
  UserX,
} from '@lucide/vue';
import type { Component } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';
import EmptyState from '@/components/EmptyState.vue';
import PageHeader from '@/components/PageHeader.vue';
import type { AppNotification, NotificationType } from '@/lib/models';
import { timeAgo } from '@/lib/format';

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

const unread = computed(() => items.value.filter((n) => !n.isRead).length);

const groups = computed(() => {
  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);
  const today: AppNotification[] = [];
  const earlier: AppNotification[] = [];
  for (const n of items.value) (n.createdAt >= startOfToday ? today : earlier).push(n);
  return [
    { label: 'Hoy', items: today },
    { label: 'Anteriores', items: earlier },
  ].filter((g) => g.items.length);
});

const typeMeta: Record<NotificationType, { icon: Component; tile: string }> = {
  new_load: { icon: Package, tile: 'bg-blue-soft text-brand' },
  outbid: { icon: TrendingDown, tile: 'bg-danger-soft text-danger' },
  auction_closing_soon: { icon: Timer, tile: 'bg-orange-soft text-orange' },
  load_assigned: { icon: CircleCheck, tile: 'bg-success-soft text-success' },
  load_cancelled: { icon: CircleX, tile: 'bg-danger-soft text-danger' },
  status_changed: { icon: Activity, tile: 'bg-violet-50 text-violet-700' },
  registration_approved: { icon: UserCheck, tile: 'bg-success-soft text-success' },
  registration_rejected: { icon: UserX, tile: 'bg-danger-soft text-danger' },
};

function meta(type: NotificationType) {
  return typeMeta[type] ?? { icon: Bell, tile: 'bg-blue-soft text-brand' };
}

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
    <PageHeader
      title="Avisos"
      :subtitle="unread ? `${unread} sin leer` : 'Estás al día'"
    >
      <template v-if="unread" #actions>
        <button type="button" class="cc-btn-ghost" @click="markAll">
          <CheckCheck class="size-4" aria-hidden="true" />
          Marcar todo como leído
        </button>
      </template>
    </PageHeader>

    <div v-if="!items.length" class="cc-card">
      <EmptyState
        title="Sin avisos"
        subtitle="Cuando haya novedades de cargas, ofertas o tu cuenta, aparecerán aquí."
      >
        <template #icon><BellOff /></template>
      </EmptyState>
    </div>

    <div v-else class="space-y-6">
      <section v-for="g in groups" :key="g.label">
        <p class="cc-eyebrow mb-2 px-1">{{ g.label }}</p>
        <div class="cc-card divide-y divide-line overflow-hidden">
          <button
            v-for="n in g.items"
            :key="n.id"
            type="button"
            class="relative flex w-full items-start gap-3.5 px-4 py-4 text-left transition hover:bg-background/70"
            :class="!n.isRead && 'bg-blue-soft/25'"
            @click="open(n.id, n.loadId)"
          >
            <span class="cc-icon-tile" :class="meta(n.type).tile">
              <component :is="meta(n.type).icon" class="size-[18px]" aria-hidden="true" />
            </span>
            <div class="min-w-0 flex-1">
              <div class="flex items-baseline justify-between gap-3">
                <p class="text-sm text-navy" :class="n.isRead ? 'font-medium' : 'font-semibold'">
                  {{ n.title }}
                </p>
                <span class="shrink-0 text-[11.5px] text-muted">{{ timeAgo(n.createdAt) }}</span>
              </div>
              <p class="mt-0.5 text-[13px] leading-snug text-muted">{{ n.body }}</p>
            </div>
            <span
              v-if="!n.isRead"
              class="absolute right-4 top-[2.6rem] size-2 rounded-full bg-orange"
              aria-label="Sin leer"
            />
          </button>
        </div>
      </section>
    </div>
  </div>
</template>
