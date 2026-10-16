const STORAGE_KEY = 'cc.savedLogin';

export interface SavedLogin {
  email: string;
  password: string;
}

export function readSavedLogin(): SavedLogin {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { email: '', password: '' };
    const parsed = JSON.parse(raw) as Partial<SavedLogin>;
    return {
      email: typeof parsed.email === 'string' ? parsed.email : '',
      password: typeof parsed.password === 'string' ? parsed.password : '',
    };
  } catch {
    return { email: '', password: '' };
  }
}

export function writeSavedLogin(email: string, password: string): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify({ email, password }));
}
