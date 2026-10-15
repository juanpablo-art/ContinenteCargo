import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';

export function startAppListeners() {
  const auth = useAuthStore();
  if (!auth.currentUser) return;
  useDataStore().startListeners();
}

export function stopAppListeners() {
  useDataStore().stopListeners();
}
