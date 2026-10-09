<script setup lang="ts">
import { useAuthStore } from '@/stores/auth';

const auth = useAuthStore();
</script>

<template>
  <div class="min-h-dvh">
    <div
      v-if="auth.isCheckingAuth"
      class="flex min-h-dvh flex-col items-center justify-center gap-5 bg-background"
    >
      <img
        src="/brand/logo-mark.png"
        alt="Continente Conecta"
        class="size-[88px] rounded-[20px] object-cover shadow-sm"
        width="88"
        height="88"
      />
      <div
        class="size-8 animate-spin rounded-full border-2 border-blue/30 border-t-blue"
        aria-label="Cargando"
      />
    </div>
    <RouterView v-else />
  </div>
</template>
