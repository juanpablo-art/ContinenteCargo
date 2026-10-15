<script setup lang="ts">
import { CircleCheck, CircleAlert, Info, X } from '@lucide/vue';
import { dismissToast, toasts } from '@/lib/toast';

const icons = { success: CircleCheck, error: CircleAlert, info: Info };
const tones = {
  success: 'text-success',
  error: 'text-danger',
  info: 'text-brand',
};
</script>

<template>
  <div
    class="pointer-events-none fixed inset-x-0 top-0 z-[60] flex flex-col items-center gap-2 px-4 pt-[max(env(safe-area-inset-top),0.75rem)] md:bottom-6 md:left-auto md:right-6 md:top-auto md:items-end md:px-0"
    aria-live="polite"
  >
    <TransitionGroup
      enter-active-class="transition duration-300 ease-out"
      enter-from-class="opacity-0 -translate-y-2 md:translate-y-2 scale-95"
      leave-active-class="transition duration-200 ease-in absolute"
      leave-to-class="opacity-0 scale-95"
      move-class="transition duration-300"
    >
      <div
        v-for="t in toasts"
        :key="t.id"
        class="pointer-events-auto flex w-full max-w-sm items-start gap-3 rounded-2xl border border-line bg-card/95 p-3.5 pr-2 shadow-elevated backdrop-blur"
        role="status"
      >
        <component :is="icons[t.tone]" class="mt-0.5 size-5 shrink-0" :class="tones[t.tone]" />
        <div class="min-w-0 flex-1">
          <p class="text-sm font-semibold text-navy">{{ t.title }}</p>
          <p v-if="t.description" class="mt-0.5 text-[13px] leading-snug text-muted">
            {{ t.description }}
          </p>
        </div>
        <button
          type="button"
          class="rounded-lg p-1 text-muted transition hover:bg-background hover:text-navy"
          aria-label="Cerrar"
          @click="dismissToast(t.id)"
        >
          <X class="size-4" />
        </button>
      </div>
    </TransitionGroup>
  </div>
</template>
