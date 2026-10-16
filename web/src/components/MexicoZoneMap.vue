<script setup lang="ts">
import { MEXICO_MAP_ZONES, polygonPoints, zoneLevel } from '@/lib/zone-maps';

const selected = defineModel<Set<string>>({ required: true });

const width = 142;
const height = 100;

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
      <h3 class="text-base font-semibold text-navy">Selecciona tus zonas de operación</h3>
      <p class="mt-0.5 text-xs leading-relaxed text-muted">
        Toca una zona para agregar todos sus estados. Después puedes quitar los que no cubres.
      </p>
    </div>

    <svg
      :viewBox="`0 0 ${width} ${height}`"
      class="aspect-[1.42] w-full overflow-hidden rounded-lg shadow-card"
      role="group"
      aria-label="Mapa de zonas de México"
    >
      <rect :width="width" :height="height" fill="#212121" />
      <g v-for="zone in MEXICO_MAP_ZONES" :key="zone.id">
        <polygon
          :points="polygonPoints(zone.polygon, width, height)"
          :fill="zoneLevel(zone.states, selected) === 'none' ? '#333333' : zone.color"
          :fill-opacity="zoneLevel(zone.states, selected) === 'partial' ? 0.65 : 1"
          :stroke="zoneLevel(zone.states, selected) === 'none' ? 'rgba(255,255,255,0.22)' : '#ffffff'"
          :stroke-width="zoneLevel(zone.states, selected) === 'full' ? 1.6 : zoneLevel(zone.states, selected) === 'partial' ? 1.15 : 0.6"
          class="cursor-pointer"
          role="button"
          tabindex="0"
          :aria-label="`Zona ${zone.id}`"
          :aria-pressed="zoneLevel(zone.states, selected) !== 'none'"
          @click="toggleZone(zone.states)"
          @keydown.enter.prevent="toggleZone(zone.states)"
          @keydown.space.prevent="toggleZone(zone.states)"
        />
        <text
          :x="zone.anchor[0] * width"
          :y="zone.anchor[1] * height"
          text-anchor="middle"
          dominant-baseline="middle"
          fill="#ffffff"
          :fill-opacity="zoneLevel(zone.states, selected) === 'none' ? 0.45 : 1"
          :font-size="zone.compact ? 4.6 : 5.2"
          font-weight="700"
          class="pointer-events-none"
        >
          {{ zone.shortLabel }}
        </text>
        <text
          v-if="zoneLevel(zone.states, selected) === 'partial'"
          :x="zone.anchor[0] * width"
          :y="zone.anchor[1] * height + 5.2"
          text-anchor="middle"
          fill="#ffffff"
          font-size="3.4"
          font-weight="700"
          class="pointer-events-none"
        >
          {{ selectedIn(zone.states).length }}/{{ zone.states.length }}
        </text>
      </g>
    </svg>

    <div v-if="selected.size" class="space-y-2">
      <p class="text-[11px] text-muted">Estados seleccionados — toca × para quitar uno</p>
      <div v-for="zone in MEXICO_MAP_ZONES" :key="`${zone.id}-chips`" class="space-y-1.5">
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
