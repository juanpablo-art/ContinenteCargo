import { createRouter, createWebHistory } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { homePathForRole, homeRouteNameForRole } from '@/lib/role-home';
import type { UserRole } from '@/lib/models';

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/login',
      name: 'login',
      component: () => import('@/views/LoginView.vue'),
      meta: { guest: true },
    },
    {
      path: '/register',
      name: 'register',
      component: () => import('@/views/RegisterView.vue'),
      meta: { guest: true },
    },
    {
      path: '/',
      component: () => import('@/layouts/AppLayout.vue'),
      meta: { requiresAuth: true },
      children: [
        {
          path: '',
          name: 'home',
          redirect: () => {
            const auth = useAuthStore();
            return homePathForRole(auth.currentUser?.role);
          },
        },
        // Admin
        {
          path: 'admin/dashboard',
          name: 'admin-dashboard',
          component: () => import('@/views/admin/AdminDashboardView.vue'),
          meta: { requiresAuth: true, roles: ['admin'] as UserRole[], title: 'Inicio' },
        },
        {
          path: 'admin/loads',
          name: 'admin-loads',
          component: () => import('@/views/admin/AdminLoadsListView.vue'),
          meta: { requiresAuth: true, roles: ['admin'] as UserRole[], title: 'Cargas' },
        },
        {
          path: 'admin/loads/new',
          name: 'admin-load-new',
          component: () => import('@/views/admin/PublishLoadView.vue'),
          meta: {
            requiresAuth: true,
            roles: ['admin'] as UserRole[],
            title: 'Publicar carga',
          },
        },
        {
          path: 'admin/loads/:id',
          name: 'admin-load-detail',
          component: () => import('@/views/admin/AdminLoadDetailView.vue'),
          meta: {
            requiresAuth: true,
            roles: ['admin', 'pricer'] as UserRole[],
            title: 'Detalle de carga',
          },
        },
        {
          path: 'admin/carriers',
          name: 'admin-carriers',
          component: () => import('@/views/admin/CarrierDirectoryView.vue'),
          meta: {
            requiresAuth: true,
            roles: ['admin'] as UserRole[],
            title: 'Transportistas',
          },
        },
        {
          path: 'admin/carriers/:id',
          name: 'admin-carrier-detail',
          component: () => import('@/views/admin/AdminCarrierDetailView.vue'),
          meta: {
            requiresAuth: true,
            roles: ['admin'] as UserRole[],
            title: 'Transportista',
          },
        },
        {
          path: 'admin/directory',
          name: 'admin-directory',
          component: () => import('@/views/admin/AdminDirectoryView.vue'),
          meta: {
            requiresAuth: true,
            roles: ['admin'] as UserRole[],
            title: 'Directorio',
          },
        },
        {
          path: 'admin/invitations',
          name: 'admin-invitations',
          component: () => import('@/views/admin/AdminInvitationsView.vue'),
          meta: {
            requiresAuth: true,
            roles: ['admin'] as UserRole[],
            title: 'Invitación manual',
          },
        },
        {
          path: 'admin/units',
          name: 'admin-units',
          component: () => import('@/views/admin/AdminUnitsView.vue'),
          meta: { requiresAuth: true, roles: ['admin'] as UserRole[], title: 'Unidades' },
        },
        {
          path: 'pricer/dashboard',
          name: 'pricer-dashboard',
          component: () => import('@/views/pricer/PricerDashboardView.vue'),
          meta: { requiresAuth: true, roles: ['pricer'] as UserRole[], title: 'Inicio' },
        },
        {
          path: 'pricer/loads',
          name: 'pricer-loads',
          component: () => import('@/views/pricer/PricerHomeView.vue'),
          meta: { requiresAuth: true, roles: ['pricer'] as UserRole[], title: 'Mis cargas' },
        },
        {
          path: 'pricer/carriers',
          name: 'pricer-carriers',
          component: () => import('@/views/pricer/PricerCarriersView.vue'),
          meta: {
            requiresAuth: true,
            roles: ['pricer'] as UserRole[],
            title: 'Mis transportistas',
          },
        },
        {
          path: 'pricer/directory',
          name: 'pricer-directory',
          component: () => import('@/views/admin/AdminDirectoryView.vue'),
          meta: { requiresAuth: true, roles: ['pricer'] as UserRole[], title: 'Directorio' },
        },
        {
          path: 'pricer/invitations',
          name: 'pricer-invitations',
          component: () => import('@/views/admin/AdminInvitationsView.vue'),
          meta: { requiresAuth: true, roles: ['pricer'] as UserRole[], title: 'Invitación manual' },
        },
        // Carrier / independent operator
        {
          path: 'carrier/home',
          name: 'carrier-home',
          component: () => import('@/views/carrier/CarrierHomeView.vue'),
          meta: {
            requiresAuth: true,
            roles: ['carrier', 'independent_operator'] as UserRole[],
            title: 'Cargas',
          },
        },
        {
          path: 'carrier/loads/:id',
          name: 'carrier-load-detail',
          component: () => import('@/views/carrier/CarrierLoadDetailView.vue'),
          meta: {
            requiresAuth: true,
            roles: ['carrier', 'independent_operator'] as UserRole[],
            title: 'Detalle de carga',
          },
        },
        {
          path: 'carrier/offers',
          name: 'carrier-offers',
          component: () => import('@/views/carrier/MyOffersView.vue'),
          meta: {
            requiresAuth: true,
            roles: ['carrier', 'independent_operator'] as UserRole[],
            title: 'Mis ofertas',
          },
        },
        {
          path: 'carrier/trips',
          name: 'carrier-trips',
          component: () => import('@/views/carrier/MyTripsView.vue'),
          meta: {
            requiresAuth: true,
            roles: ['carrier', 'independent_operator'] as UserRole[],
            title: 'Mis viajes',
          },
        },
        {
          path: 'carrier/trips/:id',
          name: 'carrier-trip-detail',
          component: () => import('@/views/carrier/TripDetailView.vue'),
          meta: {
            requiresAuth: true,
            roles: ['carrier', 'independent_operator'] as UserRole[],
            title: 'Detalle de viaje',
          },
        },
        {
          path: 'carrier/units',
          name: 'carrier-units',
          component: () => import('@/views/carrier/MyUnitsView.vue'),
          meta: {
            requiresAuth: true,
            roles: ['carrier', 'independent_operator'] as UserRole[],
            title: 'Unidades',
          },
        },
        {
          path: 'carrier/availability',
          name: 'carrier-availability',
          component: () => import('@/views/carrier/CarrierAvailabilityView.vue'),
          meta: {
            requiresAuth: true,
            roles: ['carrier', 'independent_operator'] as UserRole[],
            title: 'Disponibilidad',
          },
        },
        // Shared
        {
          path: 'notifications',
          name: 'notifications',
          component: () => import('@/views/shared/NotificationsView.vue'),
          meta: {
            requiresAuth: true,
            roles: ['admin', 'pricer', 'carrier', 'independent_operator'] as UserRole[],
            title: 'Avisos',
          },
        },
        {
          path: 'profile',
          name: 'profile',
          component: () => import('@/views/shared/ProfileView.vue'),
          meta: {
            requiresAuth: true,
            roles: ['admin', 'pricer', 'carrier', 'independent_operator'] as UserRole[],
            title: 'Perfil',
          },
        },
      ],
    },
    {
      path: '/:pathMatch(.*)*',
      redirect: '/',
    },
  ],
  scrollBehavior() {
    return { top: 0 };
  },
});

router.beforeEach(async (to) => {
  const auth = useAuthStore();
  if (auth.isCheckingAuth) {
    await auth.restoreSession();
  }
  if (to.meta.requiresAuth && !auth.isLoggedIn) {
    return { name: 'login' };
  }
  if (to.meta.guest && auth.isLoggedIn) {
    return { name: homeRouteNameForRole(auth.currentUser?.role) };
  }

  const roles = to.meta.roles as UserRole[] | undefined;
  if (roles?.length && auth.currentUser && !roles.includes(auth.currentUser.role)) {
    return homePathForRole(auth.currentUser.role);
  }

  return true;
});

export default router;
