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
  <div v-if="user" class="cc-page-narrow">
    <button type="button" class="mb-3 text-sm text-blue" @click="router.back()">← Volver</button>
    <h1 class="cc-h1">{{ user.name }}</h1>
    <dl class="mt-5 cc-card p-4 md:p-5">
      <InfoRow label="Rol" :value="user.role" />
      <InfoRow label="Status" :value="user.status" />
      <InfoRow label="Email" :value="user.email" />
      <InfoRow label="Teléfono" :value="user.phone" />
      <InfoRow label="LTL" :value="user.handlesLTL ? 'Sí' : 'No'" />
      <InfoRow label="Estados" :value="user.coverageStates.join(', ') || '—'" />
    </dl>
    <section class="mt-6">
      <h2 class="cc-eyebrow mb-2">Rutas</h2>
      <ul class="space-y-2">
        <li
          v-for="r in user.routes"
          :key="r.id"
          class="cc-card rounded-xl px-3 py-2 text-sm"
        >
          {{ r.originState }} {{ r.bidirectional ? '↔' : '→' }} {{ r.destinationState }}
        </li>
        <li v-if="!user.routes.length" class="text-sm text-muted">Sin rutas explícitas</li>
      </ul>
    </section>
  </div>
  <div v-else class="p-8 text-center text-muted">Transportista no encontrado</div>
</template>
