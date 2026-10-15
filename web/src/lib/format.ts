import type { Currency, LoadStatus, OfferStatus } from '@/lib/models';

const dateFmt = new Intl.DateTimeFormat('es-MX', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  hour: 'numeric',
  minute: '2-digit',
  hour12: true,
});

const dayFmt = new Intl.DateTimeFormat('es-MX', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
});

export function formatDateTime(d?: Date | null) {
  if (!d || Number.isNaN(d.getTime())) return '—';
  return dateFmt.format(d);
}

export function formatDate(d?: Date | null) {
  if (!d || Number.isNaN(d.getTime())) return '—';
  return dayFmt.format(d);
}

export function formatShortDate(d?: Date | null) {
  return formatDate(d);
}

export function formatMoney(amount: number, currency: Currency = 'MXN') {
  const n = new Intl.NumberFormat('es-MX', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount || 0);
  return `${currency} $${n}`;
}

export function toDatetimeLocalValue(d: Date) {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function fromDatetimeLocalValue(value: string): Date {
  return new Date(value);
}

export function statusBadgeClass(status: string): string {
  switch (status as LoadStatus | OfferStatus | string) {
    case 'Publicado':
    case 'Activa':
    case 'Ganando':
      return 'bg-blue-soft text-blue-ink';
    case 'Asignado':
    case 'Ganadora':
    case 'Disponible':
    case 'Aprobado':
    case 'approved':
      return 'bg-success-soft text-success';
    case 'Parcial':
    case 'PendienteAprobacion':
    case 'Pendiente':
    case 'pending_approval':
    case 'Superada':
    case 'Reservada':
      return 'bg-orange-soft text-orange';
    case 'Entregado':
    case 'Perdida':
    case 'Fuera de servicio':
      return 'bg-slate-100 text-slate-600';
    case 'Cancelado':
    case 'Cancelada':
    case 'Rechazada':
    case 'Rechazado':
    case 'rejected':
    case 'suspended':
      return 'bg-danger-soft text-danger';
    case 'En tránsito':
    case 'Cargado':
    case 'En camino a recolección':
    case 'En origen':
    case 'En viaje':
      return 'bg-violet-50 text-violet-700';
    default:
      return 'bg-blue-soft text-navy';
  }
}

export function deadlineTone(deadline: Date): 'danger' | 'warn' | 'ok' {
  const ms = deadline.getTime() - Date.now();
  if (ms < 0) return 'danger';
  if (ms < 3600000 * 3) return 'warn';
  return 'ok';
}

export function timeRemaining(deadline: Date): string {
  const ms = deadline.getTime() - Date.now();
  if (ms <= 0) return 'Cerrado';
  const h = Math.floor(ms / 3600000);
  const m = Math.floor((ms % 3600000) / 60000);
  if (h >= 24) {
    const d = Math.floor(h / 24);
    return `Cierra en ${d}d ${h % 24}h`;
  }
  if (h > 0) return `Cierra en ${h}h ${m}m`;
  return `Cierra en ${m}m`;
}

const STATUS_LABELS: Record<string, string> = {
  PendienteAprobacion: 'Pendiente de aprobación',
  pending_approval: 'Pendiente',
  approved: 'Aprobado',
  rejected: 'Rechazado',
  suspended: 'Suspendido',
};

export function statusLabel(status: string): string {
  return STATUS_LABELS[status] ?? status;
}

export function timeAgo(d: Date): string {
  const s = Math.round((Date.now() - d.getTime()) / 1000);
  if (s < 60) return 'Justo ahora';
  const m = Math.round(s / 60);
  if (m < 60) return `Hace ${m} min`;
  const h = Math.round(m / 60);
  if (h < 24) return `Hace ${h} h`;
  const days = Math.round(h / 24);
  if (days === 1) return 'Ayer';
  if (days < 7) return `Hace ${days} días`;
  return formatDate(d);
}

export function initials(name?: string | null): string {
  const parts = (name || '').trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return 'CC';
  return (parts[0][0] + (parts[1]?.[0] ?? '')).toUpperCase();
}

export function unitStatusClass(status: string): string {
  return statusBadgeClass(status);
}

export function offerStatusClass(status: string): string {
  return statusBadgeClass(status);
}
