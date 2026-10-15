<script setup lang="ts">
defineProps<{
  title: string;
  subtitle?: string;
}>();
</script>

<template>
  <div class="flex flex-col items-center justify-center px-6 py-16 text-center">
    <div class="mb-4 flex size-14 items-center justify-center rounded-2xl bg-blue-soft text-brand">
      <slot name="icon" />
    </div>
    <h2 class="text-base font-semibold text-navy">{{ title }}</h2>
    <p v-if="subtitle" class="mt-1 max-w-sm text-sm text-muted">{{ subtitle }}</p>
  </div>
</template>
