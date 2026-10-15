<script setup lang="ts">
import { computed } from 'vue';
import { Bell } from '@lucide/vue';
import { useRouter } from 'vue-router';
import { useDataStore } from '@/stores/data';

const router = useRouter();
const store = useDataStore();

const unread = computed(() => store.unreadCount);

function openNotifications() {
  void router.push({ name: 'notifications' });
}
</script>

<template>
  <button
    type="button"
    class="relative inline-flex size-10 items-center justify-center rounded-full border border-line bg-card text-navy shadow-card transition hover:border-blue/30 hover:text-brand"
    aria-label="Notificaciones"
    :title="unread ? `${unread} avisos sin leer` : 'Avisos'"
    @click="openNotifications"
  >
    <Bell class="size-[18px]" aria-hidden="true" />
    <span
      v-if="unread > 0"
      class="absolute -right-1 -top-1 flex h-[18px] min-w-[18px] items-center justify-center rounded-full bg-orange px-1 text-[10px] font-bold text-white ring-2 ring-background"
    >
      {{ unread > 9 ? '9+' : unread }}
    </span>
  </button>
</template>
