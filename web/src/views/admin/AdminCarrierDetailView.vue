<script setup lang="ts">
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import InfoRow from '@/components/InfoRow.vue';
import { useDataStore } from '@/stores/data';

const route = useRoute();
const router = useRouter();
const store = useDataStore();
const user = computed(() => store.users.find((u) => u.uuid === String(route.params.id)));
</script>

<template>
  <div v-if="user" class="mx-auto w-full max-w-2xl px-4 py-6 sm:px-6">
    <button type="button" class="mb-3 text-sm text-blue" @click="router.back()">← Volver</button>
    <h1 class="text-2xl font-bold text-navy">{{ user.name }}</h1>
    <dl class="mt-5 rounded-2xl border border-line bg-card p-4">
      <InfoRow label="Rol" :value="user.role" />
      <InfoRow label="Status" :value="user.status" />
      <InfoRow label="Email" :value="user.email" />
      <InfoRow label="Teléfono" :value="user.phone" />
      <InfoRow label="LTL" :value="user.handlesLTL ? 'Sí' : 'No'" />
      <InfoRow label="Estados" :value="user.coverageStates.join(', ') || '—'" />
    </dl>
    <section class="mt-6">
      <h2 class="mb-2 text-sm font-semibold uppercase text-muted">Rutas</h2>
      <ul class="space-y-2">
        <li
          v-for="r in user.routes"
          :key="r.id"
          class="rounded-xl border border-line bg-card px-3 py-2 text-sm"
        >
          {{ r.originState }} {{ r.bidirectional ? '↔' : '→' }} {{ r.destinationState }}
        </li>
        <li v-if="!user.routes.length" class="text-sm text-muted">Sin rutas explícitas</li>
      </ul>
    </section>
  </div>
  <div v-else class="p-8 text-center text-muted">Transportista no encontrado</div>
</template>
