<script setup lang="ts">
defineProps<{
  title: string;
  description?: string;
}>();
</script>

<template>
  <div class="mx-auto w-full max-w-3xl px-4 py-8 sm:px-6">
    <h1 class="text-2xl font-bold tracking-tight text-navy">{{ title }}</h1>
    <p class="mt-2 max-w-lg text-sm leading-relaxed text-muted">
      {{ description || 'Pantalla en construcción. El layout y la navegación ya están listos.' }}
    </p>
    <div
      class="mt-8 flex min-h-[12rem] items-center justify-center rounded-2xl border border-dashed border-line bg-card/60 px-6 py-10 text-center text-sm text-muted"
    >
      Placeholder
    </div>
  </div>
</template>
