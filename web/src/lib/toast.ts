import { reactive } from 'vue';

export type ToastTone = 'success' | 'error' | 'info';

export interface ToastItem {
  id: number;
  tone: ToastTone;
  title: string;
  description?: string;
}

let seq = 0;

export const toasts = reactive<ToastItem[]>([]);

export function dismissToast(id: number) {
  const idx = toasts.findIndex((t) => t.id === id);
  if (idx >= 0) toasts.splice(idx, 1);
}

function push(tone: ToastTone, title: string, description?: string, ms = 3800) {
  const id = ++seq;
  toasts.push({ id, tone, title, description });
  if (toasts.length > 4) toasts.shift();
  window.setTimeout(() => dismissToast(id), ms);
  return id;
}

export const toast = {
  success: (title: string, description?: string) => push('success', title, description),
  error: (title: string, description?: string) => push('error', title, description, 5500),
  info: (title: string, description?: string) => push('info', title, description),
};
