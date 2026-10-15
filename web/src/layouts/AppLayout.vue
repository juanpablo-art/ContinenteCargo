<script setup lang="ts">
import { computed } from 'vue';
import { useRoute, useRouter, RouterLink, RouterView } from 'vue-router';
import {
  House,
  FileText,
  Users,
  Truck,
  UserCircle,
  PackageSearch,
  Map,
  Bell,
  Car,
  LogOut,
} from '@lucide/vue';
import { useAuthStore } from '@/stores/auth';
import NotificationBell from '@/components/NotificationBell.vue';
import type { Component } from 'vue';

interface NavItem {
  name: string;
  label: string;
  icon: Component;
}

const auth = useAuthStore();
const route = useRoute();
const router = useRouter();

const isAdmin = computed(() => auth.currentUser?.role === 'admin');

const adminNav: NavItem[] = [
  { name: 'admin-dashboard', label: 'Inicio', icon: House },
  { name: 'admin-loads', label: 'Cargas', icon: FileText },
  { name: 'admin-carriers', label: 'Transportistas', icon: Users },
  { name: 'admin-units', label: 'Unidades', icon: Truck },
  { name: 'notifications', label: 'Avisos', icon: Bell },
  { name: 'profile', label: 'Perfil', icon: UserCircle },
];

const carrierNav: NavItem[] = [
  { name: 'carrier-home', label: 'Cargas', icon: Truck },
  { name: 'carrier-offers', label: 'Mis ofertas', icon: PackageSearch },
  { name: 'carrier-trips', label: 'Mis viajes', icon: Map },
  { name: 'carrier-units', label: 'Unidades', icon: Car },
  { name: 'carrier-availability', label: 'Disponib.', icon: FileText },
  { name: 'profile', label: 'Perfil', icon: UserCircle },
];

const navItems = computed(() => (isAdmin.value ? adminNav : carrierNav));

const roleLabel = computed(() => {
  switch (auth.currentUser?.role) {
    case 'admin':
      return 'Administrador';
    case 'carrier':
      return 'Línea transportista';
    case 'independent_operator':
      return 'Operador independiente';
    default:
      return '';
  }
});

const pageTitle = computed(() => {
  const match = navItems.value.find((item) => item.name === route.name);
  if (match) return match.label;
  const title = route.meta.title;
  return typeof title === 'string' ? title : 'Continente Conecta';
});

function isActive(name: string) {
  if (route.name === name) return true;
  // Keep parent nav highlighted on nested detail routes
  if (name === 'admin-loads' && String(route.name || '').startsWith('admin-load')) {
    return true;
  }
  if (name === 'carrier-home' && String(route.name || '').startsWith('carrier-load')) {
    return true;
  }
  if (name === 'carrier-trips' && String(route.name || '').startsWith('carrier-trip')) {
    return true;
  }
  return false;
}

async function logout() {
  const { stopAppListeners } = await import('@/lib/realtime');
  stopAppListeners();
  await auth.logout();
  await router.push({ name: 'login' });
}
</script>

<template>
  <div class="flex min-h-dvh bg-background text-foreground">
    <!-- Desktop sidebar (>768px) -->
    <aside
      class="sticky top-0 hidden h-dvh w-60 shrink-0 flex-col border-r border-line bg-navy-deep bg-gradient-to-b from-navy-deep via-navy to-navy-soft text-white md:flex"
    >
      <div class="flex items-center gap-3 px-5 py-5">
        <img
          src="/brand/logo-mark.png"
          alt=""
          class="size-10 rounded-xl object-cover ring-1 ring-white/15"
          width="40"
          height="40"
        />
        <div class="min-w-0">
          <img
            src="/brand/wordmark.png"
            alt="Continente Cargo"
            class="h-4 w-auto max-w-[9.5rem] object-contain brightness-0 invert"
          />
          <p class="mt-1 truncate text-[11px] text-white/65">Continente Conecta</p>
        </div>
      </div>

      <nav class="mt-2 flex flex-1 flex-col gap-1 px-3" aria-label="Principal">
        <RouterLink
          v-for="item in navItems"
          :key="item.name"
          :to="{ name: item.name }"
          class="flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition"
          :class="
            isActive(item.name)
              ? 'bg-white/15 text-white shadow-sm ring-1 ring-inset ring-white/10'
              : 'text-white/75 hover:bg-white/10 hover:text-white'
          "
        >
          <component :is="item.icon" class="size-[18px] shrink-0" aria-hidden="true" />
          <span>{{ item.label }}</span>
        </RouterLink>
      </nav>

      <div class="border-t border-white/10 px-4 py-4">
        <p class="truncate text-sm font-semibold">{{ auth.currentUser?.name }}</p>
        <p class="truncate text-xs text-white/60">{{ roleLabel }}</p>
        <button
          type="button"
          class="mt-3 inline-flex w-full items-center justify-center gap-2 rounded-xl bg-white/10 px-3 py-2 text-xs font-semibold text-white ring-1 ring-inset ring-white/15 transition hover:bg-white/15"
          @click="logout"
        >
          <LogOut class="size-3.5" aria-hidden="true" />
          Cerrar sesión
        </button>
      </div>
    </aside>

    <!-- Main column -->
    <div class="flex min-w-0 flex-1 flex-col">
      <header
        class="sticky top-0 z-20 flex h-14 items-center justify-between gap-3 border-b border-line bg-background/90 px-4 backdrop-blur md:px-6"
      >
        <div class="flex min-w-0 items-center gap-3 md:gap-0">
          <img
            src="/brand/logo-mark.png"
            alt=""
            class="size-8 rounded-lg object-cover md:hidden"
            width="32"
            height="32"
          />
          <div class="min-w-0">
            <p class="truncate text-sm font-semibold text-navy md:text-base">
              {{ pageTitle }}
            </p>
            <p class="truncate text-[11px] text-muted md:hidden">{{ roleLabel }}</p>
          </div>
        </div>
        <NotificationBell />
      </header>

      <main class="flex-1 pb-20 md:pb-0">
        <RouterView />
      </main>
    </div>

    <!-- Mobile bottom nav (<768px) -->
    <nav
      class="fixed inset-x-0 bottom-0 z-30 border-t border-line bg-card/95 pb-[env(safe-area-inset-bottom)] backdrop-blur md:hidden"
      aria-label="Principal"
    >
      <ul
        class="mx-auto grid max-w-lg"
        :style="{ gridTemplateColumns: `repeat(${navItems.length}, minmax(0, 1fr))` }"
      >
        <li v-for="item in navItems" :key="item.name">
          <RouterLink
            :to="{ name: item.name }"
            class="flex flex-col items-center gap-0.5 px-1 py-2 text-[10px] font-medium transition"
            :class="
              isActive(item.name) ? 'text-brand' : 'text-muted hover:text-navy'
            "
          >
            <component :is="item.icon" class="size-5" aria-hidden="true" />
            <span class="max-w-full truncate">{{ item.label }}</span>
          </RouterLink>
        </li>
      </ul>
    </nav>
  </div>
</template>
