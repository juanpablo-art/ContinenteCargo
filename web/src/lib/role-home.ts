import type { UserRole } from '@/lib/models';

/** Post-login / root home path for each role. */
export function homePathForRole(role: UserRole | null | undefined): string {
  if (role === 'admin') return '/admin/dashboard';
  if (role === 'pricer') return '/pricer/loads';
  if (role === 'carrier' || role === 'independent_operator') return '/carrier/home';
  return '/login';
}

export function homeRouteNameForRole(
  role: UserRole | null | undefined,
): 'admin-dashboard' | 'pricer-loads' | 'carrier-home' | 'login' {
  if (role === 'admin') return 'admin-dashboard';
  if (role === 'pricer') return 'pricer-loads';
  if (role === 'carrier' || role === 'independent_operator') return 'carrier-home';
  return 'login';
}
