<script setup lang="ts">
import { onBeforeUnmount, watch } from 'vue';

const props = defineProps<{
  open: boolean;
  title: string;
  confirmLabel?: string;
  danger?: boolean;
}>();
const emit = defineEmits<{ close: []; confirm: [] }>();

function onKey(e: KeyboardEvent) {
  if (e.key === 'Escape') emit('close');
}

watch(
  () => props.open,
  (open) => {
    if (open) window.addEventListener('keydown', onKey);
    else window.removeEventListener('keydown', onKey);
  },
  { immediate: true },
);

onBeforeUnmount(() => window.removeEventListener('keydown', onKey));
</script>

<template>
  <Teleport to="body">
    <Transition
      enter-active-class="transition duration-200 ease-out"
      enter-from-class="opacity-0"
      leave-active-class="transition duration-150 ease-in"
      leave-to-class="opacity-0"
    >
      <div
        v-if="open"
        class="fixed inset-0 z-50 flex items-end justify-center bg-navy-deep/45 backdrop-blur-[2px] sm:items-center sm:p-4"
        role="dialog"
        aria-modal="true"
        @click.self="$emit('close')"
      >
        <div
          class="w-full max-w-md animate-cc-in rounded-t-3xl bg-card p-6 pb-[max(env(safe-area-inset-bottom),1.5rem)] shadow-elevated sm:rounded-2xl sm:pb-6"
        >
          <div class="mx-auto -mt-2 mb-4 h-1 w-10 rounded-full bg-line sm:hidden" aria-hidden="true" />
          <h3 class="text-lg font-bold tracking-[-0.01em] text-navy">{{ title }}</h3>
          <div class="mt-2 text-sm leading-relaxed text-muted">
            <slot />
          </div>
          <div class="mt-6 flex flex-col-reverse gap-2 sm:flex-row">
            <button type="button" class="cc-btn-secondary sm:flex-1" @click="$emit('close')">
              Cancelar
            </button>
            <button
              type="button"
              :class="danger ? 'cc-btn-danger' : 'cc-btn'"
              class="sm:flex-1"
              @click="$emit('confirm')"
            >
              {{ confirmLabel || 'Confirmar' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
