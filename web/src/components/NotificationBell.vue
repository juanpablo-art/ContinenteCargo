<script setup lang="ts">
import { Bell } from '@lucide/vue';
import { useRouter } from 'vue-router';
import { useDataStore } from '@/stores/data';

const router = useRouter();
const store = useDataStore();

function openNotifications() {
  void router.push({ name: 'notifications' });
}
</script>

<template>
  <button
    type="button"
    class="relative inline-flex size-10 items-center justify-center rounded-xl text-navy transition hover:bg-blue-soft/70"
    aria-label="Notificaciones"
    @click="openNotifications"
  >
    <Bell class="size-5" aria-hidden="true" />
    <span
      v-if="store.unreadCount > 0"
      class="absolute right-1 top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-orange px-1 text-[10px] font-bold text-white"
    >
      {{ store.unreadCount > 9 ? '9+' : store.unreadCount }}
    </span>
  </button>
</template>
