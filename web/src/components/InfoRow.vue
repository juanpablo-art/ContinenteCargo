<script setup lang="ts">
defineProps<{ label: string; value?: string | number | null }>();
</script>

<template>
  <div class="flex items-start justify-between gap-4 py-1.5 text-sm">
    <dt class="shrink-0 text-muted">{{ label }}</dt>
    <dd class="text-right font-medium text-ink">
      <slot>{{ value ?? '—' }}</slot>
    </dd>
  </div>
</template>
