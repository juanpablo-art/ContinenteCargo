<script setup lang="ts">
const on = defineModel<boolean>({ required: true });

defineProps<{
  title: string;
  hint?: string;
  label: string;
}>();
</script>

<template>
  <div class="flex items-start justify-between gap-4 py-1">
    <div class="min-w-0">
      <p class="text-sm text-ink">{{ title }}</p>
      <p v-if="hint" class="mt-0.5 text-xs leading-relaxed text-muted">{{ hint }}</p>
    </div>
    <button
      type="button"
      role="switch"
      :aria-checked="on"
      :aria-label="label"
      class="relative mt-0.5 h-7 w-12 shrink-0 rounded-full transition"
      :class="on ? 'bg-brand' : 'bg-[rgb(214_222_234)]'"
      @click="on = !on"
    >
      <span
        class="absolute top-0.5 size-6 rounded-full bg-white shadow-md transition-all duration-200"
        :class="on ? 'left-[22px]' : 'left-0.5'"
      />
    </button>
  </div>
</template>
