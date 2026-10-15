<script setup lang="ts">
import type { Component } from 'vue';
import type { RouteLocationRaw } from 'vue-router';

withDefaults(
  defineProps<{
    label: string;
    value: string | number;
    icon?: Component;
    hint?: string;
    tone?: 'blue' | 'orange' | 'success' | 'danger' | 'navy';
    to?: RouteLocationRaw;
  }>(),
  { tone: 'blue' },
);

const tiles = {
  blue: 'bg-blue-soft text-brand',
  orange: 'bg-orange-soft text-orange',
  success: 'bg-success-soft text-success',
  danger: 'bg-danger-soft text-danger',
  navy: 'bg-navy/[0.07] text-navy',
};
</script>

<template>
  <component
    :is="to ? 'router-link' : 'div'"
    :to="to"
    class="group flex flex-col gap-3 p-4 md:p-5"
    :class="to ? 'cc-card-interactive' : 'cc-card'"
  >
    <div class="flex items-center justify-between">
      <span class="text-[13px] font-medium text-muted">{{ label }}</span>
      <span v-if="icon" class="flex size-8 items-center justify-center rounded-lg" :class="tiles[tone]">
        <component :is="icon" class="size-4" aria-hidden="true" />
      </span>
    </div>
    <div>
      <p class="text-[28px] font-bold leading-none tracking-[-0.02em] tabular-nums text-navy">
        {{ value }}
      </p>
      <p v-if="hint" class="mt-1.5 text-xs text-muted">{{ hint }}</p>
    </div>
  </component>
</template>
