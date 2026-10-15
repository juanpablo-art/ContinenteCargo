<script setup lang="ts">
import { formatDateTime } from '@/lib/format';

defineProps<{
  originCity: string;
  originState: string;
  destinationCity: string;
  destinationState: string;
  pickupDate?: Date;
  deliveryDate?: Date;
  pickupAddress?: string;
  deliveryAddress?: string;
}>();
</script>

<template>
  <ol class="relative space-y-5">
    <span
      class="absolute bottom-[1.6rem] left-[11px] top-[1.6rem] w-0.5 rounded-full bg-gradient-to-b from-brand/40 via-line to-orange/40"
      aria-hidden="true"
    />
    <li class="relative flex gap-3.5">
      <span
        class="relative z-[1] mt-0.5 flex size-6 shrink-0 items-center justify-center rounded-full bg-blue-soft ring-4 ring-card"
      >
        <span class="size-2.5 rounded-full border-2 border-brand bg-card" />
      </span>
      <div class="min-w-0">
        <p class="cc-eyebrow">Origen</p>
        <p class="mt-0.5 text-[17px] font-semibold leading-snug text-navy">
          {{ originCity }}, {{ originState }}
        </p>
        <p v-if="pickupAddress" class="mt-0.5 text-[13px] text-muted">{{ pickupAddress }}</p>
        <p v-if="pickupDate" class="mt-0.5 text-[13px] text-ink/70">
          Recolección · {{ formatDateTime(pickupDate) }}
        </p>
      </div>
    </li>
    <li class="relative flex gap-3.5">
      <span
        class="relative z-[1] mt-0.5 flex size-6 shrink-0 items-center justify-center rounded-full bg-orange-soft ring-4 ring-card"
      >
        <span class="size-2.5 rounded-full bg-orange" />
      </span>
      <div class="min-w-0">
        <p class="cc-eyebrow">Destino</p>
        <p class="mt-0.5 text-[17px] font-semibold leading-snug text-navy">
          {{ destinationCity }}, {{ destinationState }}
        </p>
        <p v-if="deliveryAddress" class="mt-0.5 text-[13px] text-muted">{{ deliveryAddress }}</p>
        <p v-if="deliveryDate" class="mt-0.5 text-[13px] text-ink/70">
          Entrega · {{ formatDateTime(deliveryDate) }}
        </p>
      </div>
    </li>
  </ol>
</template>
