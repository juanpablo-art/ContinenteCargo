<script setup lang="ts">
import { X } from '@lucide/vue';
import type { Component } from 'vue';

defineProps<{ title: string; subtitle?: string; icon?: Component }>();
defineEmits<{ close: [] }>();
</script>

<template>
  <section class="cc-card animate-cc-in overflow-hidden">
    <header class="flex items-start gap-3 border-b border-line bg-background/50 px-4 py-3.5 md:px-5">
      <span v-if="icon" class="cc-icon-tile size-9">
        <component :is="icon" class="size-[18px]" aria-hidden="true" />
      </span>
      <div class="min-w-0 flex-1">
        <h2 class="cc-h2">{{ title }}</h2>
        <p v-if="subtitle" class="mt-0.5 text-xs text-muted">{{ subtitle }}</p>
      </div>
      <button
        type="button"
        class="-mr-1 flex size-8 items-center justify-center rounded-lg text-muted transition hover:bg-card hover:text-navy"
        aria-label="Cerrar"
        @click="$emit('close')"
      >
        <X class="size-4" />
      </button>
    </header>
    <div class="space-y-4 p-4 md:p-5">
      <slot />
    </div>
  </section>
</template>
