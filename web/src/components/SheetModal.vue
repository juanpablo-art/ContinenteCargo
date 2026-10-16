<script setup lang="ts">
import { computed, onBeforeUnmount, watch } from 'vue';
import { X } from '@lucide/vue';
import { useMobileActionBar } from '@/lib/mobile-action-bar';

const props = defineProps<{ open: boolean; title: string; subtitle?: string }>();
const emit = defineEmits<{ close: [] }>();
const { keyboardInset } = useMobileActionBar();
const panelStyle = computed(() =>
  keyboardInset.value > 0
    ? {
        marginBottom: `${keyboardInset.value}px`,
        maxHeight: `calc(92dvh - ${keyboardInset.value}px)`,
      }
    : undefined,
);

function onKey(e: KeyboardEvent) {
  if (e.key === 'Escape') emit('close');
}

watch(
  () => props.open,
  (open) => {
    document.body.style.overflow = open ? 'hidden' : '';
    if (open) window.addEventListener('keydown', onKey);
    else window.removeEventListener('keydown', onKey);
  },
  { immediate: true },
);

onBeforeUnmount(() => {
  document.body.style.overflow = '';
  window.removeEventListener('keydown', onKey);
});
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
        class="fixed inset-0 z-50 flex items-end justify-center bg-navy-deep/45 backdrop-blur-[2px] sm:items-center sm:p-6"
        role="dialog"
        aria-modal="true"
        @click.self="emit('close')"
      >
        <div
          class="flex max-h-[92dvh] w-full max-w-xl animate-cc-in flex-col overflow-hidden rounded-t-3xl bg-card shadow-elevated sm:rounded-2xl"
          :style="panelStyle"
        >
          <header class="flex items-start gap-3 border-b border-line px-5 pb-4 pt-5">
            <div class="min-w-0 flex-1">
              <h2 class="text-lg font-bold tracking-[-0.01em] text-navy">{{ title }}</h2>
              <p v-if="subtitle" class="mt-0.5 text-sm text-muted">{{ subtitle }}</p>
            </div>
            <button
              type="button"
              class="-mr-1 flex size-9 items-center justify-center rounded-full text-muted transition hover:bg-background hover:text-navy"
              aria-label="Cerrar"
              @click="emit('close')"
            >
              <X class="size-5" />
            </button>
          </header>
          <div class="flex-1 overflow-y-auto px-5 py-5">
            <slot />
          </div>
          <footer
            v-if="$slots.footer"
            class="flex gap-2 border-t border-line bg-background/50 px-5 py-4 pb-[max(env(safe-area-inset-bottom),1rem)]"
          >
            <slot name="footer" />
          </footer>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
