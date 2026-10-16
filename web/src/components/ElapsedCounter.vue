<script setup lang="ts">
import { computed } from 'vue';
import { formatElapsed, useNow } from '@/lib/clock';

const props = defineProps<{ since: Date }>();

const now = useNow();
const elapsed = computed(() => formatElapsed(props.since, now.value));
const ageMs = computed(() => now.value - (props.since?.getTime?.() || now.value));
const tone = computed(() => {
  if (ageMs.value >= 6 * 3600000) return 'text-danger';
  if (ageMs.value >= 2 * 3600000) return 'text-orange';
  return 'text-navy';
});
const dot = computed(() => (ageMs.value >= 6 * 3600000 ? 'bg-danger' : 'bg-orange'));
</script>

<template>
  <span
    class="inline-flex items-center gap-1.5 font-mono font-bold tabular-nums"
    :class="tone"
    :aria-label="`Lleva ${elapsed} publicada sin transportista`"
  >
    <span class="relative flex size-2 shrink-0" aria-hidden="true">
      <span class="absolute inline-flex size-full animate-ping rounded-full opacity-70" :class="dot" />
      <span class="relative size-2 rounded-full" :class="dot" />
    </span>
    {{ elapsed }}
  </span>
</template>
