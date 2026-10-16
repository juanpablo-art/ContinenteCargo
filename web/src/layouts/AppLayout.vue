<script setup lang="ts">
import { computed } from 'vue';
import { useRoute, useRouter, RouterLink, RouterView } from 'vue-router';
import {
  LayoutDashboard,
  Package,
  Users,
  Truck,
  UserCircle,
  HandCoins,
  Route as RouteIcon,
  Bell,
  Radio,
  LogOut,
  Search,
  BookUser,
} from '@lucide/vue';
import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';
import { loadAwaitingCarrier } from '@/lib/models';
import NotificationBell from '@/components/NotificationBell.vue';
import { initials } from '@/lib/format';
import type { Component } from 'vue';

interface NavItem {
  name: string;
  label: string;
  short?: string;
  icon: Component;
  /** Route-name prefixes that keep this item highlighted. */
  match?: string[];
  mobile?: boolean;
}

interface NavGroup {
  label: string;
  items: NavItem[];
}

const auth = useAuthStore();
const store = useDataStore();
const route = useRoute();
const router = useRouter();

const isAdmin = computed(() => auth.currentUser?.role === 'admin');

const adminGroups: NavGroup[] = [
  {
    label: 'Operación',
    items: [
      { name: 'admin-dashboard', label: 'Inicio', icon: LayoutDashboard, mobile: true },
      { name: 'admin-loads', label: 'Cargas', icon: Package, match: ['admin-load'], mobile: true },
      {
        name: 'admin-carriers',
        label: 'Transportistas',
        icon: Users,
        match: ['admin-carrier', 'admin-invitations', 'admin-directory'],
        mobile: true,
      },
      { name: 'admin-units', label: 'Unidades', icon: Truck, mobile: true },
    ],
  },
  {
    label: 'Cuenta',
    items: [
      { name: 'notifications', label: 'Avisos', icon: Bell },
      { name: 'profile', label: 'Perfil', icon: UserCircle },
    ],
  },
];

const carrierGroups: NavGroup[] = [
  {
    label: 'Operación',
    items: [
      { name: 'carrier-home', label: 'Cargas disponibles', short: 'Cargas', icon: Search, match: ['carrier-load'], mobile: true },
      { name: 'carrier-offers', label: 'Mis ofertas', short: 'Ofertas', icon: HandCoins, mobile: true },
      { name: 'carrier-trips', label: 'Mis viajes', short: 'Viajes', icon: RouteIcon, match: ['carrier-trip'], mobile: true },
      { name: 'carrier-units', label: 'Mis unidades', short: 'Unidades', icon: Truck, mobile: true },
      { name: 'carrier-availability', label: 'Disponibilidad', short: 'Disponible', icon: Radio, mobile: true },
    ],
  },
  {
    label: 'Cuenta',
    items: [
      { name: 'notifications', label: 'Avisos', icon: Bell },
      { name: 'profile', label: 'Perfil', icon: UserCircle },
    ],
  },
];

const pricerGroups: NavGroup[] = [
  {
    label: 'Operación',
    items: [
      { name: 'pricer-dashboard', label: 'Inicio', icon: LayoutDashboard, mobile: true },
      { name: 'pricer-loads', label: 'Cargas', icon: Package, match: ['admin-load-detail'], mobile: true },
      { name: 'pricer-carriers', label: 'Transportistas', short: 'Transp.', icon: Users, mobile: true },
      {
        name: 'pricer-directory',
        label: 'Directorio',
        short: 'Directorio',
        icon: BookUser,
        match: ['pricer-invitations', 'pricer-carrier-profile'],
        mobile: true,
      },
    ],
  },
  {
    label: 'Cuenta',
    items: [{ name: 'profile', label: 'Perfil', icon: UserCircle, mobile: true }],
  },
];

const groups = computed(() => {
  if (isAdmin.value) return adminGroups;
  if (auth.currentUser?.role === 'pricer') return pricerGroups;
  return carrierGroups;
});
const mobileItems = computed(() => groups.value.flatMap((g) => g.items).filter((i) => i.mobile));

const roleLabel = computed(() => {
  switch (auth.currentUser?.role) {
    case 'admin':
      return 'Administrador';
    case 'carrier':
      return 'Línea transportista';
    case 'independent_operator':
      return 'Operador independiente';
    case 'pricer':
      return 'Pricer';
    default:
      return '';
  }
});

const userInitials = computed(() => initials(auth.currentUser?.name));
const unread = computed(() => store.unreadCount);
const openLoadCount = computed(() =>
  auth.currentUser?.role === 'pricer' ? store.loads.filter(loadAwaitingCarrier).length : 0,
);

const todayLabel = computed(() => {
  const label = new Intl.DateTimeFormat('es-MX', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
  }).format(new Date());
  return label.charAt(0).toUpperCase() + label.slice(1);
});

const pageTitle = computed(() => {
  const title = route.meta.title;
  return typeof title === 'string' ? title : 'Continente Conecta';
});

function isActive(item: NavItem) {
  const current = String(route.name || '');
  if (current === item.name) return true;
  return (item.match ?? []).some((prefix) => current.startsWith(prefix));
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
    <!-- Desktop sidebar -->
    <aside
      class="sticky top-0 hidden h-dvh w-[248px] shrink-0 flex-col overflow-hidden bg-navy-deep text-white md:flex"
    >
      <div
        class="pointer-events-none absolute inset-0 bg-[radial-gradient(120%_60%_at_0%_0%,rgb(0_87_184/0.35),transparent_60%),radial-gradient(80%_50%_at_100%_100%,rgb(10_63_107/0.6),transparent_70%)]"
        aria-hidden="true"
      />

      <RouterLink to="/" class="relative flex items-center gap-3 px-5 pb-6 pt-6">
        <span
          class="flex size-10 items-center justify-center rounded-xl bg-white/10 ring-1 ring-inset ring-white/15"
        >
          <img
            src="/brand/logo-mark.png"
            alt=""
            class="size-8 object-contain brightness-0 invert"
            width="32"
            height="32"
          />
        </span>
        <div class="min-w-0 leading-tight">
          <p class="text-[15px] font-bold tracking-[-0.01em]">Continente</p>
          <p class="text-[11px] font-semibold uppercase tracking-[0.16em] text-white/50">Conecta</p>
        </div>
      </RouterLink>

      <nav class="relative flex flex-1 flex-col gap-6 overflow-y-auto px-3" aria-label="Principal">
        <div v-for="group in groups" :key="group.label">
          <p class="mb-2 px-3 text-[10.5px] font-semibold uppercase tracking-[0.1em] text-white/40">
            {{ group.label }}
          </p>
          <div class="flex flex-col gap-0.5">
            <RouterLink
              v-for="item in group.items"
              :key="item.name"
              :to="{ name: item.name }"
              class="group relative flex items-center gap-3 rounded-xl px-3 py-2.5 text-[14px] font-medium transition duration-150"
              :class="
                isActive(item)
                  ? 'bg-white/[0.12] text-white shadow-[inset_0_1px_0_rgb(255_255_255/0.06)]'
                  : 'text-white/65 hover:bg-white/[0.06] hover:text-white'
              "
            >
              <span
                v-if="isActive(item)"
                class="absolute -left-3 top-1/2 h-5 w-1 -translate-y-1/2 rounded-r-full bg-white"
                aria-hidden="true"
              />
              <component
                :is="item.icon"
                class="size-[18px] shrink-0 transition"
                :class="isActive(item) ? 'text-white' : 'text-white/55 group-hover:text-white/90'"
                aria-hidden="true"
              />
              <span class="flex-1 truncate">{{ item.label }}</span>
              <span
                v-if="item.name === 'notifications' && unread > 0"
                class="rounded-full bg-orange px-1.5 py-px text-[10.5px] font-bold text-white"
              >
                {{ unread > 99 ? '99+' : unread }}
              </span>
              <span
                v-else-if="item.name === 'pricer-loads' && openLoadCount > 0"
                class="rounded-full bg-orange px-1.5 py-px text-[10.5px] font-bold text-white"
              >
                {{ openLoadCount > 99 ? '99+' : openLoadCount }}
              </span>
            </RouterLink>
          </div>
        </div>
      </nav>

      <div class="relative m-3 rounded-2xl bg-white/[0.06] p-3 ring-1 ring-inset ring-white/10">
        <div class="flex items-center gap-3">
          <RouterLink
            :to="{ name: 'profile' }"
            class="flex size-9 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-blue to-navy-soft text-[13px] font-bold ring-2 ring-white/15"
          >
            {{ userInitials }}
          </RouterLink>
          <div class="min-w-0 flex-1">
            <p class="truncate text-[13.5px] font-semibold leading-tight">
              {{ auth.currentUser?.name }}
            </p>
            <p class="truncate text-[11.5px] text-white/55">{{ roleLabel }}</p>
          </div>
          <button
            type="button"
            class="flex size-8 shrink-0 items-center justify-center rounded-lg text-white/60 transition hover:bg-white/10 hover:text-white"
            title="Cerrar sesión"
            aria-label="Cerrar sesión"
            @click="logout"
          >
            <LogOut class="size-4" aria-hidden="true" />
          </button>
        </div>
      </div>
    </aside>

    <!-- Main column -->
    <div class="flex min-w-0 flex-1 flex-col">
      <header
        class="sticky top-0 z-20 border-b border-line/80 bg-background/80 pt-[env(safe-area-inset-top)] backdrop-blur-xl backdrop-saturate-150"
      >
        <div class="flex h-14 items-center justify-between gap-3 px-4 md:h-16 md:px-8">
          <div class="flex min-w-0 items-center gap-2.5">
            <RouterLink to="/" class="shrink-0 md:hidden">
              <img
                src="/brand/logo-mark.png"
                alt="Inicio"
                class="size-8 rounded-[9px] object-cover shadow-sm"
                width="32"
                height="32"
              />
            </RouterLink>
            <div class="min-w-0">
              <p class="truncate text-[15px] font-semibold leading-tight text-navy md:hidden">
                {{ pageTitle }}
              </p>
              <p class="hidden text-sm text-muted md:block">{{ todayLabel }}</p>
            </div>
          </div>
          <div class="flex items-center gap-1.5">
            <NotificationBell />
            <RouterLink
              :to="{ name: 'profile' }"
              class="flex size-9 items-center justify-center rounded-full bg-navy text-[12.5px] font-bold text-white ring-2 ring-card transition hover:ring-blue/30 md:hidden"
              aria-label="Perfil"
            >
              {{ userInitials }}
            </RouterLink>
          </div>
        </div>
      </header>

      <main class="flex-1 pb-[calc(5rem+env(safe-area-inset-bottom))] md:pb-0">
        <RouterView />

      </main>
    </div>

    <!-- Mobile bottom nav -->
    <nav
      class="fixed inset-x-0 bottom-0 z-30 border-t border-line/80 bg-card/90 pb-[env(safe-area-inset-bottom)] shadow-[0_-8px_24px_-12px_rgb(16_36_58/0.12)] backdrop-blur-xl backdrop-saturate-150 md:hidden"
      aria-label="Principal"
    >
      <ul
        class="mx-auto grid max-w-lg px-1"
        :style="{ gridTemplateColumns: `repeat(${mobileItems.length}, minmax(0, 1fr))` }"
      >
        <li v-for="item in mobileItems" :key="item.name">
          <RouterLink
            :to="{ name: item.name }"
            class="flex flex-col items-center gap-1 px-0.5 pb-1.5 pt-2 text-[10.5px] font-semibold transition"
            :class="isActive(item) ? 'text-brand' : 'text-muted active:text-navy'"
          >
            <span
              class="relative flex h-7 w-12 items-center justify-center rounded-full transition duration-200"
              :class="isActive(item) ? 'bg-blue-soft' : ''"
            >
              <component :is="item.icon" class="size-[19px]" :stroke-width="isActive(item) ? 2.3 : 2" aria-hidden="true" />
              <span
                v-if="item.name === 'pricer-loads' && openLoadCount > 0"
                class="absolute right-1.5 top-0.5 size-2 rounded-full bg-orange ring-2 ring-card"
              />
            </span>
            <span class="max-w-full truncate">{{ item.short || item.label }}</span>
          </RouterLink>
        </li>
      </ul>
    </nav>
  </div>
</template>
