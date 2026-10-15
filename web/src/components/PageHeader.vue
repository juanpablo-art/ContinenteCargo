<script setup lang="ts">
import { ChevronLeft } from '@lucide/vue';
import { useRouter, type RouteLocationRaw } from 'vue-router';

const props = defineProps<{
  title: string;
  subtitle?: string;
  eyebrow?: string;
  back?: RouteLocationRaw | true;
  backLabel?: string;
}>();

const router = useRouter();

function goBack() {
  if (props.back === true) router.back();
  else if (props.back) void router.push(props.back);
}
</script>

<template>
  <header class="mb-5 md:mb-7">
    <button v-if="back" type="button" class="cc-back" @click="goBack">
      <ChevronLeft class="size-4" aria-hidden="true" />
      {{ backLabel || 'Regresar' }}
    </button>
    <div class="flex flex-wrap items-end justify-between gap-x-4 gap-y-3">
      <div class="min-w-0">
        <p v-if="eyebrow" class="cc-eyebrow mb-1">{{ eyebrow }}</p>
        <h1 class="cc-h1">{{ title }}</h1>
        <p v-if="subtitle" class="mt-1 text-sm text-muted">{{ subtitle }}</p>
        <slot name="meta" />
      </div>
      <div v-if="$slots.actions" class="flex shrink-0 items-center gap-2">
        <slot name="actions" />
      </div>
    </div>
  </header>
</template>
