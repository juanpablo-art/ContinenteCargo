<script setup lang="ts">
import StatusBadge from '@/components/StatusBadge.vue';
import type { Offer } from '@/lib/domain';
import { formatDateTime, formatMoney } from '@/lib/format';

defineProps<{ offer: Offer }>();
defineEmits<{ approve: []; reject: [] }>();
</script>

<template>
  <div class="rounded-xl border border-line bg-card p-3">
    <div class="flex items-start justify-between gap-2">
      <div>
        <p class="text-sm font-semibold text-navy">{{ offer.carrierName }}</p>
        <p class="text-xs text-muted">{{ formatDateTime(offer.submittedAt) }}</p>
      </div>
      <StatusBadge :status="offer.status" />
    </div>
    <div class="mt-2 flex flex-wrap gap-3 text-sm">
      <span class="font-medium text-ink">{{ formatMoney(offer.amount, offer.currency) }}</span>
      <span class="text-muted">{{ offer.availableUnitCount }} u.</span>
      <span v-if="offer.proposedPrice" class="text-muted">
        Prop. {{ formatMoney(offer.proposedPrice, offer.currency) }}/u
      </span>
    </div>
    <div
      v-if="offer.status === 'PendienteAprobacion'"
      class="mt-3 flex gap-2"
    >
      <button type="button" class="cc-btn flex-1 !h-10 text-sm" @click="$emit('approve')">
        Aprobar
      </button>
      <button
        type="button"
        class="cc-btn-secondary flex-1 !h-10 text-sm"
        @click="$emit('reject')"
      >
        Rechazar
      </button>
    </div>
  </div>
</template>
