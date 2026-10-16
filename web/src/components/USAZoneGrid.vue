<script setup lang="ts">
import { CheckCircle2 } from '@lucide/vue';
import { USA_MAP_ZONES, zoneLevel } from '@/lib/zone-maps';

const selected = defineModel<Set<string>>({ required: true });

function selectedIn(states: readonly string[]): string[] {
  return states.filter((state) => selected.value.has(state));
}

function toggleZone(states: readonly string[]) {
  const next = new Set(selected.value);
  if (zoneLevel(states, next) === 'full') {
    states.forEach((state) => next.delete(state));
  } else {
    states.forEach((state) => next.add(state));
  }
  selected.value = next;
}

function removeState(state: string) {
  const next = new Set(selected.value);
  next.delete(state);
  selected.value = next;
}
</script>

<template>
  <section class="space-y-3 rounded-2xl border border-line bg-background p-3.5">
    <div>
      <h3 class="text-base font-semibold text-navy">Selecciona tus zonas en EE.UU.</h3>
      <p class="mt-0.5 text-xs leading-relaxed text-muted">
        Toca una zona para agregar todos sus estados. Después puedes quitar los que no cubres.
      </p>
    </div>

    <div class="grid grid-cols-3 gap-2">
      <button
        v-for="zone in USA_MAP_ZONES"
        :key="zone.id"
        type="button"
        class="flex min-h-[92px] flex-col items-center justify-center gap-1 rounded-[10px] px-1 py-3 text-center transition"
        :class="zoneLevel(zone.states, selected) === 'none' ? 'border border-line bg-card' : 'text-white'"
        :style="
          zoneLevel(zone.states, selected) === 'none'
            ? undefined
            : {
                backgroundColor: zone.color,
                opacity: zoneLevel(zone.states, selected) === 'partial' ? 0.72 : 1,
              }
        "
        :aria-pressed="zoneLevel(zone.states, selected) !== 'none'"
        @click="toggleZone(zone.states)"
      >
        <CheckCircle2
          v-if="zoneLevel(zone.states, selected) === 'full'"
          class="size-3.5 text-white"
          aria-hidden="true"
        />
        <span
          class="text-xs font-bold leading-tight"
          :class="zoneLevel(zone.states, selected) === 'none' ? 'text-ink' : 'text-white'"
        >
          {{ zone.shortLabel }}
        </span>
        <span
          class="text-[10px] leading-tight"
          :class="zoneLevel(zone.states, selected) === 'none' ? 'text-muted' : 'text-white/85'"
        >
          {{ zone.keyStates }}
        </span>
        <span
          v-if="zoneLevel(zone.states, selected) === 'partial'"
          class="text-[10px] font-bold text-white"
        >
          {{ selectedIn(zone.states).length }}/{{ zone.states.length }}
        </span>
      </button>
    </div>

    <div v-if="selected.size" class="space-y-2">
      <p class="text-[11px] text-muted">Estados seleccionados — toca × para quitar uno</p>
      <div v-for="zone in USA_MAP_ZONES" :key="`${zone.id}-chips`">
        <div v-if="selectedIn(zone.states).length" class="flex gap-1.5 overflow-x-auto pb-1">
          <span
            class="shrink-0 rounded-full px-2 py-1 text-[10px] font-bold"
            :style="{ color: zone.color, backgroundColor: `${zone.color}1f` }"
          >
            {{ zone.shortLabel }}
          </span>
          <button
            v-for="state in selectedIn(zone.states)"
            :key="state"
            type="button"
            class="inline-flex shrink-0 items-center gap-1 rounded-full px-2 py-1 text-[11px] font-medium"
            :style="{ color: zone.color, backgroundColor: `${zone.color}26` }"
            :aria-label="`Quitar ${state}`"
            @click="removeState(state)"
          >
            {{ state }}
            <span aria-hidden="true" class="text-[10px] font-bold">×</span>
          </button>
        </div>
      </div>
    </div>
  </section>
</template>
