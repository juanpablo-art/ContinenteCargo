<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';

const auth = useAuthStore();
const router = useRouter();

const roleLabel = computed(() => {
  switch (auth.currentUser?.role) {
    case 'admin':
      return 'Administrador';
    case 'carrier':
      return 'Línea Transportista';
    case 'independent_operator':
      return 'Operador Independiente';
    default:
      return '';
  }
});

const firstName = computed(
  () => auth.currentUser?.name.split(' ')[0] || 'Usuario',
);

async function logout() {
  await auth.logout();
  await router.push({ name: 'login' });
}
</script>

<template>
  <div class="min-h-dvh bg-background">
    <header
      class="border-b border-line bg-navy-deep bg-gradient-to-r from-navy-deep to-navy px-5 py-4 text-white"
    >
      <div class="mx-auto flex max-w-lg items-center justify-between gap-3">
        <div class="flex items-center gap-3">
          <img
            src="/brand/logo-mark.png"
            alt=""
            class="size-10 rounded-xl object-cover"
          />
          <div>
            <p class="text-sm font-semibold leading-tight">Continente Conecta</p>
            <p class="text-xs text-white/70">{{ roleLabel }}</p>
          </div>
        </div>
        <button
          type="button"
          class="rounded-lg bg-white/10 px-3 py-2 text-xs font-semibold ring-1 ring-inset ring-white/15 hover:bg-white/15"
          @click="logout"
        >
          Cerrar sesión
        </button>
      </div>
    </header>

    <main class="mx-auto max-w-lg px-5 py-10">
      <h1 class="text-2xl font-bold text-navy">Hola, {{ firstName }}</h1>
      <p class="mt-2 text-sm leading-relaxed text-muted">
        Sesión iniciada correctamente. La web solo incluye registro e inicio de
        sesión por ahora; cargas, ofertas y unidades llegarán cuando la app iOS
        esté completa.
      </p>

      <div class="mt-8 space-y-3 rounded-2xl border border-line bg-card p-5">
        <p class="text-xs font-medium uppercase tracking-wide text-muted">
          Tu cuenta
        </p>
        <dl class="space-y-3 text-sm">
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Nombre</dt>
            <dd class="font-medium text-ink">{{ auth.currentUser?.name }}</dd>
          </div>
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Correo</dt>
            <dd class="font-medium text-ink">{{ auth.currentUser?.email }}</dd>
          </div>
          <div class="flex justify-between gap-4">
            <dt class="text-muted">Estado</dt>
            <dd class="font-medium text-success">
              {{ auth.currentUser?.status === 'approved' ? 'Aprobado' : auth.currentUser?.status }}
            </dd>
          </div>
        </dl>
      </div>
    </main>
  </div>
</template>
