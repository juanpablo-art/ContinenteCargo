<script setup lang="ts">
import { CircleCheck, CircleAlert } from '@lucide/vue';

defineProps<{ ok: boolean; title: string; body?: string; actionLabel?: string }>();
defineEmits<{ action: [] }>();
</script>

<template>
  <div class="flex flex-col items-center px-2 py-4 text-center">
    <span
      class="flex size-14 items-center justify-center rounded-full ring-8"
      :class="ok ? 'bg-success-soft text-success ring-success-soft/50' : 'bg-danger-soft text-danger ring-danger-soft/50'"
    >
      <component :is="ok ? CircleCheck : CircleAlert" class="size-7" aria-hidden="true" />
    </span>
    <p class="mt-4 text-base font-semibold text-navy">{{ title }}</p>
    <p v-if="body" class="mt-1 max-w-xs text-sm leading-relaxed text-muted">{{ body }}</p>
    <button type="button" class="cc-btn mt-5" @click="$emit('action')">
      {{ actionLabel || 'Listo' }}
    </button>
  </div>
</template>
