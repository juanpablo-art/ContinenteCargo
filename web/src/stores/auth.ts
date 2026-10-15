import { defineStore } from 'pinia';
import {
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signOut,
  sendEmailVerification,
  ActionCodeSettings,
  type AuthError,
} from 'firebase/auth';
import { waitForPendingWrites } from 'firebase/firestore';
import { auth, db } from '@/plugins/firebase';
import {
  fetchUserProfile,
  writeCompany,
  writePhoneIndex,
  writeUserProfile,
} from '@/lib/firestore-user';
import type {
  AppUser,
  CarrierRoute,
  EquipmentType,
  UserRole,
} from '@/lib/models';
import { newUuid } from '@/lib/models';

export interface RegisterPayload {
  name: string;
  email: string;
  password: string;
  phone: string;
  role: Exclude<UserRole, 'admin'>;
  companyName?: string;
  companyContact?: string;
  routes: CarrierRoute[];
  coverageStates: string[];
  coverageEquipmentTypes: EquipmentType[];
  handlesLTL: boolean;
}

function mapAuthError(error: AuthError | Error): string {
  const code = 'code' in error ? error.code : '';
  switch (code) {
    case 'auth/email-already-in-use':
      return 'Ese correo ya está registrado';
    case 'auth/weak-password':
      return 'La contraseña debe tener al menos 6 caracteres';
    case 'auth/invalid-email':
      return 'El correo no es válido';
    case 'auth/wrong-password':
    case 'auth/invalid-credential':
    case 'auth/user-not-found':
    case 'auth/user-disabled':
      return 'Correo o contraseña incorrectos';
    default:
      return error.message || 'Ocurrió un error. Intenta de nuevo.';
  }
}

export const useAuthStore = defineStore('auth', {
  state: () => ({
    currentUser: null as AppUser | null,
    isCheckingAuth: true,
    isLoading: false,
    errorMessage: null as string | null,
  }),

  getters: {
    isLoggedIn: (s) => s.currentUser != null,
  },

  actions: {
    async restoreSession() {
      this.isCheckingAuth = true;
      try {
        // DEV-only layout demos (Playwright screenshots) — never used in production.
        if (import.meta.env.DEV) {
          const demoRole = sessionStorage.getItem('ccDemoRole') as UserRole | null;
          if (
            demoRole === 'admin' ||
            demoRole === 'carrier' ||
            demoRole === 'independent_operator'
          ) {
            this.currentUser = {
              uuid: 'demo-layout',
              name: demoRole === 'admin' ? 'Admin Demo' : 'Carrier Demo',
              email: 'demo@continente.local',
              phone: '0000000000',
              role: demoRole,
              status: 'approved',
              canNegotiateRates: true,
              handlesLTL: false,
              routes: [],
              coverageStates: [],
              coverageZones: [],
              coverageEquipmentTypes: [],
            };
            return;
          }
        }

        await auth.authStateReady();
        const firebaseUser = auth.currentUser;
        if (!firebaseUser) {
          this.currentUser = null;
          return;
        }
        const profile = await fetchUserProfile(firebaseUser.uid);
        if (profile) {
          this.currentUser = profile;
        } else {
          await signOut(auth);
          this.currentUser = null;
        }
      } catch {
        this.currentUser = null;
      } finally {
        this.isCheckingAuth = false;
      }
    },

    async login(email: string, password: string) {
      this.isLoading = true;
      this.errorMessage = null;
      try {
        const result = await signInWithEmailAndPassword(auth, email, password);
        const profile = await fetchUserProfile(result.user.uid);
        if (!profile) {
          await signOut(auth);
          this.errorMessage =
            'Usuario autenticado pero sin perfil. Contacta al administrador.';
          return false;
        }
        if (profile.role !== 'admin' && profile.status !== 'approved') {
          await signOut(auth);
          this.errorMessage =
            'Tu cuenta está pendiente de aprobación. Te notificaremos cuando sea revisada.';
          return false;
        }
        this.currentUser = profile;
        return true;
      } catch (err) {
        this.errorMessage = mapAuthError(err as AuthError);
        return false;
      } finally {
        this.isLoading = false;
      }
    },

    async register(payload: RegisterPayload) {
      this.isLoading = true;
      this.errorMessage = null;
      try {
        const result = await createUserWithEmailAndPassword(
          auth,
          payload.email,
          payload.password,
        );
        const uid = result.user.uid;

        auth.languageCode = 'es';

        const actionSettings: ActionCodeSettings = {
          url: 'https://continente-conecta.firebaseapp.com/verificado',
          handleCodeInApp: false,
        };
        try {
          await sendEmailVerification(result.user, actionSettings);
        } catch {
          try {
            await sendEmailVerification(result.user);
          } catch {
            /* non-fatal */
          }
        }

        const uuid = newUuid();
        const companyId =
          payload.role === 'carrier' ? newUuid() : undefined;

        const user: AppUser = {
          uuid,
          name: payload.name,
          email: payload.email,
          phone: payload.phone,
          role: payload.role,
          status: 'pending_approval',
          companyId,
          canNegotiateRates: true,
          handlesLTL: payload.role === 'carrier' ? payload.handlesLTL : false,
          routes: payload.routes,
          coverageStates: payload.coverageStates,
          coverageZones: [],
          coverageEquipmentTypes: payload.coverageEquipmentTypes,
          createdAt: new Date(),
        };

        // Order matches iOS: users doc first (phone-index rules call callerData()),
        // then companies, then users_by_phone.
        await writeUserProfile(uid, user);
        try {
          await waitForPendingWrites(db);
        } catch {
          /* best-effort */
        }

        if (companyId) {
          try {
            await writeCompany({
              id: companyId,
              name: payload.companyName || '',
              contactName: payload.companyContact || '',
              phone: payload.phone,
              email: payload.email,
              rfc: '',
              status: 'pending_approval',
              createdAt: new Date(),
            });
          } catch {
            /* non-fatal for registration success */
          }
        }

        try {
          await writePhoneIndex(user);
        } catch {
          /* non-critical — admin still sees user via users collection */
        }

        // Match iOS: registration succeeds but user stays logged out until approved
        await signOut(auth);
        this.currentUser = null;
        return true;
      } catch (err) {
        this.errorMessage = mapAuthError(err as AuthError);
        return false;
      } finally {
        this.isLoading = false;
      }
    },

    async logout() {
      await signOut(auth);
      this.currentUser = null;
      this.errorMessage = null;
    },

    clearError() {
      this.errorMessage = null;
    },
  },
});
