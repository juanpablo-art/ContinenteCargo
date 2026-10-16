<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import {
  Search,
  MapPin,
  Phone,
  Mail,
  RefreshCw,
  Download,
  UserPlus,
  Check,
  Send,
  UserCheck,
} from '@lucide/vue';
import { useAuthStore } from '@/stores/auth';
import { demoUsers } from '@/lib/demo-data';
import {
  demoDirectoryRecords,
  directoryPhone,
  fetchCarrierDirectory,
  importCarrierDirectory,
  followUpCopy,
  inviteFromDirectory,
  registrationIndexFromContacts,
  withRegistration,
  type CarrierDirectoryRecord,
} from '@/lib/directory';
import EmptyState from '@/components/EmptyState.vue';
import PageHeader from '@/components/PageHeader.vue';
import { toast } from '@/lib/toast';

type Filter = 'unsent' | 'follow' | 'ready' | 'all';

const auth = useAuthStore();
const isAdmin = computed(() => auth.currentUser?.role === 'admin');
const isDemo = computed(() => auth.currentUser?.email === 'demo@continente.local');
const inviteRoute = computed(() => (isAdmin.value ? 'admin-invitations' : 'pricer-invitations'));
const pricerEmail = computed(() =>
  auth.currentUser?.role === 'pricer' ? auth.currentUser.email : '',
);

const records = ref<CarrierDirectoryRecord[]>([]);
const selected = ref<Set<string>>(new Set());
const search = ref('');
const filter = ref<Filter>('unsent');
const loading = ref(true);
const sending = ref(false);
const importing = ref(false);

function badgeOf(record: CarrierDirectoryRecord) {
  const copy = followUpCopy(record);
  const cls =
    record.followUp === 'ready'
      ? 'bg-success-soft text-success'
      : record.followUp === 'failed'
        ? 'bg-danger-soft text-danger'
        : record.followUp === 'issue'
          ? 'bg-orange-soft text-orange'
          : record.followUp === 'waiting'
            ? 'bg-blue-soft text-blue-ink'
            : 'bg-slate-100 text-slate-600';
  return { ...copy, cls };
}

function matchesFilter(record: CarrierDirectoryRecord, id: Filter) {
  if (id === 'unsent') return record.followUp === 'unsent';
  if (id === 'follow') return record.followUp === 'waiting' || record.followUp === 'failed' || record.followUp === 'issue';
  if (id === 'ready') return record.followUp === 'ready';
  return true;
}

function canReach(record: CarrierDirectoryRecord) {
  return Boolean(directoryPhone(record.phone) || record.email.includes('@'));
}

function canInvite(record: CarrierDirectoryRecord) {
  return canReach(record) && (record.followUp === 'unsent' || record.followUp === 'waiting' || record.followUp === 'failed');
}

const chips = computed(() => {
  const all = records.value;
  return [
    { id: 'unsent' as const, label: 'Por enviar', n: all.filter((r) => matchesFilter(r, 'unsent')).length },
    { id: 'follow' as const, label: 'Seguimiento', n: all.filter((r) => matchesFilter(r, 'follow')).length },
    { id: 'ready' as const, label: 'Listos', n: all.filter((r) => matchesFilter(r, 'ready')).length },
    { id: 'all' as const, label: 'Todos', n: all.length },
  ];
});

const unsent = computed(() => records.value.filter((r) => r.followUp === 'unsent' && canReach(r)));
const retriable = computed(() =>
  records.value.filter((r) => (r.followUp === 'waiting' || r.followUp === 'failed') && canReach(r)),
);

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase();
  return records.value
    .filter((r) => matchesFilter(r, filter.value))
    .filter((r) => {
      if (!q) return true;
      return (
        r.companyName.toLowerCase().includes(q) ||
        r.contactName.toLowerCase().includes(q) ||
        r.baseCity.toLowerCase().includes(q) ||
        r.phone.includes(q)
      );
    })
    .sort((a, b) => a.companyName.localeCompare(b.companyName, 'es'));
});

const selectable = computed(() => (isAdmin.value ? [] : filtered.value.filter((r) => canInvite(r))));
const selectedRecords = computed(() =>
  records.value.filter((r) => selected.value.has(r.id) && canInvite(r)),
);
const selectedWithPhone = computed(() => selectedRecords.value.filter((r) => directoryPhone(r.phone)));
const selectedWithEmail = computed(() => selectedRecords.value.filter((r) => r.email.includes('@')));
const allFilteredSelected = computed(
  () => selectable.value.length > 0 && selectable.value.every((r) => selected.value.has(r.id)),
);

function toggle(id: string) {
  if (isAdmin.value) return;
  const row = records.value.find((r) => r.id === id);
  if (!row || !canInvite(row)) return;
  const next = new Set(selected.value);
  if (next.has(id)) next.delete(id);
  else next.add(id);
  selected.value = next;
}

function toggleAll() {
  const next = new Set(selected.value);
  if (allFilteredSelected.value) selectable.value.forEach((r) => next.delete(r.id));
  else selectable.value.forEach((r) => next.add(r.id));
  selected.value = next;
}

function decorate(rows: CarrierDirectoryRecord[]) {
  return withRegistration(
    rows.map((row) => ({ ...row })),
    registrationIndexFromContacts(demoUsers()),
  );
}

function ownedByCurrentPricer(rows: CarrierDirectoryRecord[]) {
  if (isAdmin.value) return rows;
  const email = (auth.currentUser?.email ?? '').trim().toLowerCase();
  return rows.filter((row) => {
    const owner = row.pricerEmail.trim().toLowerCase();
    return !owner || owner === email;
  });
}

async function load() {
  loading.value = true;
  try {
    const rows = isDemo.value ? decorate(demoDirectoryRecords()) : await fetchCarrierDirectory();
    records.value = ownedByCurrentPricer(rows);
    const live = new Set(records.value.filter((r) => canInvite(r)).map((r) => r.id));
    if ([...selected.value].some((id) => !live.has(id))) {
      selected.value = new Set([...selected.value].filter((id) => live.has(id)));
    }
  } catch (e) {
    records.value = [];
    toast.error('No se pudo cargar el directorio', e instanceof Error ? e.message : undefined);
  } finally {
    loading.value = false;
  }
}

async function importDirectory() {
  if (isDemo.value) {
    toast.error('Modo demostración', 'Inicia sesión con tu cuenta de administrador para importar.');
    return;
  }
  importing.value = true;
  try {
    const result = await importCarrierDirectory();
    if (result.error) {
      toast.error('Error al importar', result.error);
    } else {
      toast.success(`${result.imported} transportistas actualizados`);
      await load();
    }
  } catch (e) {
    toast.error('Error al importar', e instanceof Error ? e.message : undefined);
  } finally {
    importing.value = false;
  }
}

function markDemoSent(targets: CarrierDirectoryRecord[]) {
  const live = demoDirectoryRecords();
  for (const target of targets) {
    const row = live.find((r) => r.id === target.id);
    if (!row || row.followUp === 'ready' || row.followUp === 'issue') continue;
    row.status = 'sent';
    if (pricerEmail.value) row.pricerEmail = pricerEmail.value;
  }
}

async function deliver(
  targets: CarrierDirectoryRecord[],
  channel: 'whatsapp' | 'email' | 'auto',
  label: string,
) {
  if (!targets.length || sending.value) return;
  sending.value = true;
  try {
    let success = targets.length;
    let failed = 0;
    if (isDemo.value) {
      markDemoSent(targets);
    } else {
      const result = await inviteFromDirectory(
        targets,
        channel,
        auth.currentUser?.uuid ?? '',
        pricerEmail.value || undefined,
      );
      success = result.success;
      failed = result.failed;
    }
    const noun = success === 1 ? 'invitación' : 'invitaciones';
    toast.success(
      `${success} ${noun} por ${label}`,
      failed
        ? `${failed} fallaron. Revisa teléfono o correo.`
        : 'Quedan en Seguimiento hasta que el registro quede listo.',
    );
    selected.value = new Set();
    await load();
  } catch (e) {
    toast.error('No se pudieron enviar', e instanceof Error ? e.message : undefined);
  } finally {
    sending.value = false;
  }
}

function inviteQueue(targets: CarrierDirectoryRecord[]) {
  const whatsapp = targets.filter((r) => directoryPhone(r.phone)).length;
  const email = targets.length - whatsapp;
  const label =
    email && whatsapp ? `WhatsApp (${whatsapp}) y correo (${email})` : whatsapp ? 'WhatsApp' : 'correo';
  return deliver(targets, 'auto', label);
}

function sendSelected() {
  return inviteQueue(selectedRecords.value);
}

onMounted(load);
</script>

<template>
  <div class="cc-page" :class="selected.size ? 'pb-28' : ''">
    <PageHeader
      :title="`Directorio${records.length ? ` (${records.length})` : ''}`"
          :subtitle="
        isAdmin
          ? 'Los pricers envían las invitaciones y revisan que cada registro quede bien'
          : 'Selecciona los transportistas y envía las invitaciones. Luego da seguimiento al registro.'
      "
      :back="isAdmin ? { name: 'admin-carriers' } : undefined"
      back-label="Transportistas"
    >
      <template #actions>
        <button type="button" class="cc-btn-secondary w-auto px-3" :disabled="loading" @click="load">
          <RefreshCw class="size-4" :class="loading && 'animate-spin'" aria-hidden="true" />
          <span class="hidden sm:inline">Refrescar</span>
        </button>
        <button
          v-if="isAdmin"
          type="button"
          class="cc-btn-secondary w-auto px-3"
          :disabled="importing"
          @click="importDirectory"
        >
          <Download class="size-4" aria-hidden="true" />
          {{ importing ? 'Importando…' : 'Actualizar' }}
        </button>
        <RouterLink v-if="!isAdmin" :to="{ name: inviteRoute }" class="cc-btn w-auto px-4">
          <UserPlus class="size-4" aria-hidden="true" />
          Invitación manual
        </RouterLink>
      </template>
    </PageHeader>

    <div v-if="loading" class="space-y-3">
      <div v-for="i in 5" :key="i" class="cc-card flex gap-3 p-4">
        <div class="cc-skeleton size-6 rounded-full" />
        <div class="flex-1 space-y-2">
          <div class="cc-skeleton h-4 w-1/2" />
          <div class="cc-skeleton h-3 w-1/3" />
        </div>
      </div>
    </div>

    <div v-else-if="!records.length" class="cc-card">
      <EmptyState
        title="Directorio vacío"
        :subtitle="
          isAdmin
            ? 'Importa el directorio. Los pricers envían cada invitación y dan seguimiento al registro.'
            : 'Cuando haya transportistas, envíales la invitación y revisa que se registren bien.'
        "
      >
        <template #icon><UserPlus /></template>
        <button
          v-if="isAdmin"
          type="button"
          class="cc-btn w-auto px-5"
          :disabled="importing"
          @click="importDirectory"
        >
          <Download class="size-4" aria-hidden="true" />
          {{ importing ? 'Importando…' : 'Importar directorio' }}
        </button>
        <RouterLink v-else :to="{ name: inviteRoute }" class="cc-btn w-auto px-5">
          <UserPlus class="size-4" aria-hidden="true" />
          Invitación manual
        </RouterLink>
      </EmptyState>
    </div>

    <template v-else>
      <section class="mb-4 flex flex-col gap-3 rounded-2xl border border-line bg-card p-4 shadow-card sm:flex-row sm:items-center sm:justify-between">
        <div class="min-w-0">
          <p class="text-sm font-semibold text-navy">
            {{
              unsent.length
                ? `${unsent.length} sin invitación`
                : retriable.length
                  ? `${retriable.length} esperando registro`
                  : 'Registros al día'
            }}
          </p>
          <p class="mt-0.5 text-xs text-muted">
            {{
              isAdmin
                ? 'Desde aquí ves el avance. El envío y el seguimiento los hace cada pricer.'
                : 'Marca uno, varios o todos. La invitación sale solo a los que seleccionaste.'
            }}
          </p>
        </div>
        <div v-if="!isAdmin && selectable.length" class="flex w-full shrink-0 flex-col gap-2 sm:w-auto sm:flex-row">
          <button type="button" class="cc-btn-secondary h-11 w-full px-4 sm:w-auto" @click="toggleAll">
            <Check class="size-4" aria-hidden="true" />
            {{ allFilteredSelected ? 'Quitar selección' : `Seleccionar todos (${selectable.length})` }}
          </button>
          <button
            v-if="selectedRecords.length"
            type="button"
            class="cc-btn h-11 w-full px-4 sm:w-auto"
            :disabled="sending"
            @click="sendSelected"
          >
            <Send class="size-4" aria-hidden="true" />
            {{
              sending
                ? 'Enviando…'
                : selectedRecords.length
                  ? selectedRecords.length === 1
                    ? 'Enviar 1 invitación'
                    : `Enviar ${selectedRecords.length} invitaciones`
                  : 'Enviar invitaciones'
            }}
          </button>
        </div>
      </section>

      <div class="mb-4 flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
        <div class="cc-scroll-x">
          <button
            v-for="chip in chips"
            :key="chip.id"
            type="button"
            class="cc-chip"
            :class="filter === chip.id && 'cc-chip-active'"
            @click="filter = chip.id"
          >
            {{ chip.label }}
            <span
              class="rounded-full px-1.5 text-[11px] font-semibold tabular-nums"
              :class="filter === chip.id ? 'bg-white/20' : 'bg-background text-muted'"
            >
              {{ chip.n }}
            </span>
          </button>
        </div>
        <div class="flex items-center gap-2">
          <label class="relative block min-w-0 flex-1 md:w-80">
            <Search class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted" />
            <input
              v-model="search"
              type="search"
              class="cc-field pl-10"
              placeholder="Empresa, contacto, ciudad o teléfono"
            />
          </label>
        </div>
      </div>

      <p v-if="!filtered.length" class="py-16 text-center text-sm text-muted">
        {{ search ? `Sin resultados para “${search}”` : 'Nadie en este filtro.' }}
      </p>

      <ul v-else class="grid gap-2.5">
        <li v-for="record in filtered" :key="record.id">
          <component
            :is="canInvite(record) && !isAdmin ? 'button' : 'div'"
            :type="canInvite(record) && !isAdmin ? 'button' : undefined"
            class="flex w-full items-start gap-3 rounded-2xl border p-3.5 text-left"
            :class="
              !canInvite(record) || isAdmin
                ? 'border-transparent bg-card shadow-card'
                : selected.has(record.id)
                  ? 'border-brand/30 bg-blue-soft/50 transition'
                  : 'border-transparent bg-card shadow-card transition hover:shadow-card-hover'
            "
            @click="canInvite(record) && !isAdmin ? toggle(record.id) : undefined"
          >
            <span
              v-if="!isAdmin"
              class="mt-0.5 flex size-6 shrink-0 items-center justify-center rounded-full border"
              :class="
                record.followUp === 'ready'
                  ? 'border-success/30 bg-success-soft text-success'
                  : !canInvite(record)
                    ? 'border-orange/30 bg-orange-soft text-orange'
                    : selected.has(record.id)
                      ? 'border-brand bg-brand text-white'
                      : 'border-line bg-card text-transparent'
              "
            >
              <UserCheck v-if="!canInvite(record)" class="size-3.5" aria-hidden="true" />
              <Check v-else class="size-3.5" aria-hidden="true" />
            </span>
            <span class="min-w-0 flex-1">
              <span class="flex items-start justify-between gap-3">
                <span class="truncate text-sm font-semibold text-navy">{{ record.companyName }}</span>
                <span class="cc-badge shrink-0" :class="badgeOf(record).cls">
                  {{ badgeOf(record).label }}
                </span>
              </span>
              <span class="mt-1 block text-xs font-medium" :class="badgeOf(record).tone">
                {{ badgeOf(record).detail }}
              </span>
              <span v-if="record.contactName" class="mt-0.5 block truncate text-xs text-muted">
                {{ record.contactName }}
              </span>
              <span v-if="record.baseCity" class="mt-1.5 flex items-center gap-1 text-xs text-muted">
                <MapPin class="size-3.5 shrink-0" aria-hidden="true" />
                {{ record.baseCity }}
              </span>
              <span class="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-muted">
                <span v-if="record.phone" class="inline-flex items-center gap-1">
                  <Phone class="size-3.5" aria-hidden="true" /> {{ record.phone }}
                </span>
                <span v-if="record.email" class="inline-flex min-w-0 items-center gap-1">
                  <Mail class="size-3.5 shrink-0" aria-hidden="true" />
                  <span class="truncate">{{ record.email }}</span>
                </span>
              </span>
              <span v-if="record.equipmentTypes.length || record.handlesLTL" class="mt-2 flex flex-wrap gap-1">
                <span
                  v-for="eq in record.equipmentTypes"
                  :key="eq"
                  class="cc-badge bg-blue-soft text-blue-ink"
                >
                  {{ eq }}
                </span>
                <span v-if="record.handlesLTL" class="cc-badge bg-orange-soft text-orange">LTL</span>
              </span>
            </span>
          </component>
        </li>
      </ul>
    </template>

    <Teleport to="body">
    <div
      v-if="!isAdmin && selected.size"
      class="fixed inset-x-0 bottom-[calc(4.5rem+env(safe-area-inset-bottom))] z-40 border-t border-line bg-card/95 px-4 py-3 shadow-elevated backdrop-blur md:bottom-0 md:left-[248px]"
    >
      <div class="mx-auto flex max-w-6xl flex-col gap-2 sm:flex-row sm:items-center">
        <div class="min-w-0">
          <p class="text-sm font-semibold text-navy">
            {{ selectedRecords.length }} seleccionado{{ selectedRecords.length === 1 ? '' : 's' }}
          </p>
          <p class="text-[11px] text-muted">
            {{ selectedWithPhone.length }} WhatsApp · {{ selectedWithEmail.length }} correo
          </p>
        </div>
        <button
          type="button"
          class="cc-btn h-11 w-full px-4 sm:ml-auto sm:w-auto"
          :disabled="!selectedRecords.length || sending"
          @click="sendSelected"
        >
          <Send class="size-4" aria-hidden="true" />
          {{
            sending
              ? 'Enviando…'
              : selectedRecords.length === 1
                ? 'Enviar 1 invitación'
                : `Enviar ${selectedRecords.length} invitaciones`
          }}
        </button>
      </div>
    </div>
    </Teleport>
  </div>
</template>
