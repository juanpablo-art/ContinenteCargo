<script setup lang="ts">
import { computed } from 'vue';
import type { LoadStatus } from '@/lib/models';

const STEPS: LoadStatus[] = [
  'Asignado',
  'En camino a recolección',
  'En origen',
  'Cargado',
  'En tránsito',
  'Entregado',
];

const props = defineProps<{ status: LoadStatus }>();

const index = computed(() => STEPS.indexOf(props.status));
</script>

<template>
  <div class="flex gap-1" :aria-label="`Etapa ${index + 1} de ${STEPS.length}`">
    <span
      v-for="(step, i) in STEPS"
      :key="step"
      class="h-1.5 flex-1 rounded-full transition-colors"
      :class="
        status === 'Cancelado'
          ? 'bg-danger-soft'
          : i < index || status === 'Entregado'
            ? 'bg-success'
            : i === index
              ? 'bg-brand'
              : 'bg-line'
      "
    />
  </div>
</template>
