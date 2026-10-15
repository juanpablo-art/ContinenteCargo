<script setup lang="ts">
defineProps<{
  title: string;
  subtitle?: string;
}>();
</script>

<template>
  <div class="flex flex-col items-center justify-center px-6 py-14 text-center">
    <div class="relative mb-5">
      <div class="absolute inset-0 -m-3 rounded-[28px] bg-blue-soft/60" aria-hidden="true" />
      <div
        class="relative flex size-14 items-center justify-center rounded-2xl border border-blue/10 bg-card text-brand shadow-card [&>svg]:size-6"
      >
        <slot name="icon" />
      </div>
    </div>
    <h2 class="text-base font-semibold text-navy">{{ title }}</h2>
    <p v-if="subtitle" class="mt-1.5 max-w-sm text-sm leading-relaxed text-muted">{{ subtitle }}</p>
    <div v-if="$slots.default" class="mt-5">
      <slot />
    </div>
  </div>
</template>
