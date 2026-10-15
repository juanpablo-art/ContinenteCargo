<script setup lang="ts">
import { computed } from 'vue';
import { loadIsFull, type Load } from '@/lib/models';
import { statusBadgeClass, statusLabel } from '@/lib/format';

const props = defineProps<{
  status?: string;
  load?: Load;
}>();

const raw = computed(() => {
  if (
    props.load &&
    props.load.confirmedUnitCount > 0 &&
    !loadIsFull(props.load) &&
    props.load.status === 'Publicado'
  ) {
    return 'Parcial';
  }
  return props.status || props.load?.status || '';
});

const tone = computed(() => statusBadgeClass(raw.value));
</script>

<template>
  <span class="cc-badge" :class="tone">
    <span class="size-1.5 rounded-full bg-current opacity-80" aria-hidden="true" />
    {{ statusLabel(raw) }}
  </span>
</template>
