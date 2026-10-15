<script setup lang="ts">
withDefaults(defineProps<{ count?: number }>(), { count: 3 });
</script>

<template>
  <div v-for="i in count" :key="i" class="cc-card p-4" aria-hidden="true">
    <div class="flex justify-between gap-3">
      <div class="flex-1 space-y-2">
        <div class="cc-skeleton h-3 w-20" />
        <div class="cc-skeleton h-4 w-3/4" />
      </div>
      <div class="cc-skeleton h-5 w-16 rounded-full" />
    </div>
    <div class="mt-4 flex gap-2">
      <div class="cc-skeleton h-6 w-24 rounded-full" />
      <div class="cc-skeleton h-6 w-20 rounded-full" />
      <div class="cc-skeleton h-6 w-16 rounded-full" />
    </div>
    <div class="mt-4 flex items-end justify-between border-t border-line pt-3">
      <div class="cc-skeleton h-5 w-32" />
      <div class="cc-skeleton h-3 w-20" />
    </div>
  </div>
</template>
