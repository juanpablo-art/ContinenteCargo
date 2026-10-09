# Continente Conecta Web

Vue 3 + Vite + Pinia + Firebase Auth/Firestore — **registration and login only** for now, aligned with the iOS Continente Conecta app.

## Stack

Patterns follow the existing `app-client-2` client portal (Vite, Vue Router, Pinia, Tailwind, Firebase via env).

## Setup

```bash
cd web
cp .env.example .env.local
# Fill VITE_FIREBASE_* from Firebase Console → Project settings → Web app
pnpm install
pnpm dev
```

Dev server defaults to http://localhost:5174

## Auth scope

- Login: email/password → Firestore `users/{uid}` profile → block pending non-admins
- Register: 2-step (basic info + coverage/routes) → Firebase Auth + `users` / `companies` / `users_by_phone` + email verification (es)
- Post-login home is a placeholder until full feature parity

## Brand

Assets under `public/brand/` (cube mark + wordmark).
