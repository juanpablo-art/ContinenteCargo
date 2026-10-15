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
    class="relative inline-flex size-10 items-center justify-center rounded-xl text-navy transition hover:bg-blue-soft/70"
    aria-label="Notificaciones"
    :title="unread ? `${unread} avisos sin leer` : 'Avisos'"
    @click="openNotifications"
  >
    <Bell class="size-5" aria-hidden="true" />
    <span
      class="absolute right-2 top-2 size-2 rounded-full bg-orange transition-opacity"
      :class="unread > 0 ? 'opacity-100' : 'opacity-0'"
      aria-hidden="true"
    />
    <span
      v-if="unread > 0"
      class="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-orange px-1 text-[10px] font-bold text-white"
    >
      {{ unread > 9 ? '9+' : unread }}
    </span>
  </button>
</template>
