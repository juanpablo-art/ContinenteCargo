<script setup lang="ts">
import { Bell } from '@lucide/vue';
import { useRouter } from 'vue-router';

const router = useRouter();

function openNotifications() {
  void router.push({ name: 'notifications' });
}
</script>

<template>
  <button
    type="button"
    class="relative inline-flex size-10 items-center justify-center rounded-xl text-navy transition hover:bg-blue-soft/70"
    aria-label="Notificaciones"
    title="Notificaciones (próximamente)"
    @click="openNotifications"
  >
    <Bell class="size-5" aria-hidden="true" />
    <!-- Placeholder badge — wired when notifications store lands -->
    <span
      class="absolute right-2 top-2 size-2 rounded-full bg-orange opacity-0"
      aria-hidden="true"
    />
  </button>
</template>
