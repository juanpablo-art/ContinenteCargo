<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { Mail, Lock } from '@lucide/vue';
import { useAuthStore } from '@/stores/auth';
import { homePathForRole } from '@/lib/role-home';

const auth = useAuthStore();
const email = ref(auth.savedEmail);
const password = ref(auth.savedPassword);
const router = useRouter();

async function onSubmit() {
  auth.clearError();
  const ok = await auth.login(email.value.trim(), password.value);
  if (ok) await router.push(homePathForRole(auth.currentUser?.role));
}
</script>

<template>
  <div class="flex min-h-dvh w-full">
    <!-- Brand panel (desktop) -->
    <aside
      class="relative hidden w-1/2 flex-col justify-between overflow-hidden bg-navy-deep bg-gradient-to-br from-navy-deep via-navy to-navy-soft py-10 pl-6 pr-10 text-white lg:flex"
    >
      <div
        class="pointer-events-none absolute right-1/4 top-1/3 h-[26rem] w-[26rem] rounded-full bg-blue/25 blur-[140px]"
        aria-hidden="true"
      />
      <img
        src="/brand/wordmark.png"
        alt="Continente Cargo"
        class="relative h-8 w-auto self-start object-contain brightness-0 invert"
      />
      <div class="relative max-w-md pl-2">
        <p class="text-xs font-medium uppercase tracking-[0.16em] text-white/70">
          Continente Conecta
        </p>
        <h2 class="mt-4 font-display text-4xl font-semibold leading-tight tracking-tight">
          Plataforma de carga para transportistas.
        </h2>
      </div>
      <span aria-hidden="true" />
    </aside>

    <!-- Form -->
    <main class="relative flex flex-1 items-center justify-center px-5 py-10 sm:px-8">
      <div
        class="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_top,_rgba(31,132,248,0.08),_transparent_55%)]"
        aria-hidden="true"
      />

      <div class="relative w-full max-w-sm">
        <div class="mb-8 flex flex-col items-center text-center">
          <img
            src="/brand/logo-mark.png"
            alt=""
            class="mb-4 size-24 rounded-[22px] object-cover shadow-sm ring-1 ring-line"
            width="96"
            height="96"
          />
          <h1 class="text-2xl font-bold tracking-tight text-navy">
            Continente Conecta
          </h1>
          <p class="mt-1 text-sm text-muted">
            Plataforma de carga Continente Cargo
          </p>
        </div>

        <form class="space-y-4" @submit.prevent="onSubmit">
          <div>
            <label class="cc-label" for="email">Correo electrónico</label>
            <div class="relative">
              <Mail
                class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted"
                aria-hidden="true"
              />
              <input
                id="email"
                v-model="email"
                type="email"
                autocomplete="username"
                required
                class="cc-field pl-10"
                placeholder="correo@empresa.com"
              />
            </div>
          </div>

          <div>
            <label class="cc-label" for="password">Contraseña</label>
            <div class="relative">
              <Lock
                class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted"
                aria-hidden="true"
              />
              <input
                id="password"
                v-model="password"
                type="password"
                autocomplete="current-password"
                required
                class="cc-field pl-10"
                placeholder="••••••••"
              />
            </div>
          </div>

          <p v-if="auth.errorMessage" class="text-left text-xs text-danger">
            {{ auth.errorMessage }}
          </p>

          <button type="submit" class="cc-btn" :disabled="auth.isLoading">
            <span
              v-if="auth.isLoading"
              class="mr-2 size-4 animate-spin rounded-full border-2 border-white/30 border-t-white"
            />
            Iniciar sesión
          </button>
        </form>

        <div class="mt-6 space-y-3">
          <div class="h-px bg-line" />
          <router-link
            :to="{ name: 'register' }"
            class="block text-center text-sm font-medium text-blue hover:text-blue-ink"
          >
            ¿No tienes cuenta? Regístrate
          </router-link>
        </div>
      </div>
    </main>
  </div>
</template>
