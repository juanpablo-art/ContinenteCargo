<script setup lang="ts">
defineProps<{ label: string; value?: string | number | null }>();
</script>

<template>
  <div class="flex items-start justify-between gap-4 border-b border-line/70 py-2.5 text-sm last:border-b-0">
    <dt class="shrink-0 text-muted">{{ label }}</dt>
    <dd class="text-right font-medium text-ink">
      <slot>{{ value ?? '—' }}</slot>
    </dd>
  </div>
</template>
