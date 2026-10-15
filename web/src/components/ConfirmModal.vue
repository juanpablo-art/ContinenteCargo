<script setup lang="ts">
defineProps<{
  open: boolean;
  title: string;
  confirmLabel?: string;
  danger?: boolean;
}>();
defineEmits<{ close: []; confirm: [] }>();
</script>

<template>
  <div
    v-if="open"
    class="fixed inset-0 z-50 flex items-end justify-center bg-navy-deep/40 p-4 sm:items-center"
    @click.self="$emit('close')"
  >
    <div class="w-full max-w-md rounded-2xl bg-card p-5 shadow-xl">
      <h3 class="text-lg font-bold text-navy">{{ title }}</h3>
      <div class="mt-3 text-sm text-muted">
        <slot />
      </div>
      <div class="mt-5 flex gap-2">
        <button type="button" class="cc-btn-secondary flex-1" @click="$emit('close')">
          Cancelar
        </button>
        <button
          type="button"
          class="cc-btn flex-1"
          :class="danger ? '!bg-danger hover:!bg-red-700' : ''"
          @click="$emit('confirm')"
        >
          {{ confirmLabel || 'Confirmar' }}
        </button>
      </div>
    </div>
  </div>
</template>
