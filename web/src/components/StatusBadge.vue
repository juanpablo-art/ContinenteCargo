<script setup lang="ts">
import { computed } from 'vue';
import { loadIsFull, type Load } from '@/lib/models';
import { statusBadgeClass } from '@/lib/format';

const props = defineProps<{
  status?: string;
  load?: Load;
}>();

const label = computed(() => {
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

const tone = computed(() => statusBadgeClass(label.value));
</script>

<template>
  <span
    class="inline-flex items-center rounded-md px-2 py-0.5 text-[11px] font-semibold"
    :class="tone"
  >
    {{ label }}
  </span>
</template>
