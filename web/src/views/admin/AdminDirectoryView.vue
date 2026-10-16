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
  MessageCircle,
  Check,
} from '@lucide/vue';
import { useAuthStore } from '@/stores/auth';
import {
  demoDirectoryRecords,
  fetchCarrierDirectory,
  importCarrierDirectory,
  inviteFromDirectory,
  type CarrierDirectoryRecord,
} from '@/lib/directory';
import EmptyState from '@/components/EmptyState.vue';
import PageHeader from '@/components/PageHeader.vue';
import { toast } from '@/lib/toast';

type Filter = 'all' | 'pending' | 'invited' | 'registered';

const auth = useAuthStore();
const isDemo = computed(() => auth.currentUser?.uuid === 'demo-layout');

const records = ref<CarrierDirectoryRecord[]>([]);
const selected = ref<Set<string>>(new Set());
const search = ref('');
const filter = ref<Filter>('all');
const loading = ref(true);
const sending = ref(false);
const importing = ref(false);

const statusOf = (status: string) => {
  if (status === 'sent') return { label: 'Invitado', cls: 'bg-blue-soft text-blue-ink' };
  if (status === 'failed') return { label: 'Fallido', cls: 'bg-danger-soft text-danger' };
  if (status === 'registered') return { label: 'Registrado', cls: 'bg-success-soft text-success' };
  return { label: 'Pendiente', cls: 'bg-slate-100 text-slate-600' };
};

function matchesFilter(record: CarrierDirectoryRecord, id: Filter) {
  if (id === 'pending') return record.status === 'pending_invitation';
  if (id === 'invited') return record.status === 'sent' || record.status === 'failed';
  if (id === 'registered') return record.status === 'registered';
  return true;
}

const chips = computed(() => {
  const all = records.value;
  return [
    { id: 'all' as const, label: 'Todos', n: all.length },
    { id: 'pending' as const, label: 'Pendientes', n: all.filter((r) => matchesFilter(r, 'pending')).length },
    { id: 'invited' as const, label: 'Invitados', n: all.filter((r) => matchesFilter(r, 'invited')).length },
    { id: 'registered' as const, label: 'Registrados', n: all.filter((r) => matchesFilter(r, 'registered')).length },
  ];
});

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

const selectedRecords = computed(() => filtered.value.filter((r) => selected.value.has(r.id)));
const selectedWithPhone = computed(() => selectedRecords.value.filter((r) => r.phone));
const selectedWithEmail = computed(() => selectedRecords.value.filter((r) => r.email));
const allFilteredSelected = computed(
  () => filtered.value.length > 0 && filtered.value.every((r) => selected.value.has(r.id)),
);

function toggle(id: string) {
  const next = new Set(selected.value);
  if (next.has(id)) next.delete(id);
  else next.add(id);
  selected.value = next;
}

function toggleAll() {
  const next = new Set(selected.value);
  if (allFilteredSelected.value) filtered.value.forEach((r) => next.delete(r.id));
  else filtered.value.forEach((r) => next.add(r.id));
  selected.value = next;
}

async function load() {
  loading.value = true;
  try {
    records.value = isDemo.value
      ? demoDirectoryRecords().map((r) => ({ ...r }))
      : await fetchCarrierDirectory();
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

async function send(channel: 'whatsapp' | 'email') {
  const targets = channel === 'whatsapp' ? selectedWithPhone.value : selectedWithEmail.value;
  if (!targets.length) return;
  sending.value = true;
  try {
    let success = targets.length;
    let failed = 0;
    if (isDemo.value) {
      const live = demoDirectoryRecords();
      for (const target of targets) {
        const row = live.find((r) => r.id === target.id);
        if (row) row.status = 'sent';
      }
    } else {
      const result = await inviteFromDirectory(
        targets,
        channel,
        auth.currentUser?.uuid ?? '',
      );
      success = result.success;
      failed = result.failed;
    }
    const label = channel === 'whatsapp' ? 'WhatsApp' : 'correo';
    toast.success(
      `${success} invitación${success === 1 ? '' : 'es'} por ${label}`,
      failed ? `${failed} fallaron. Revisa los datos.` : undefined,
    );
    selected.value = new Set();
    await load();
  } catch (e) {
    toast.error('No se pudieron enviar', e instanceof Error ? e.message : undefined);
  } finally {
    sending.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="cc-page" :class="selected.size ? 'pb-28' : ''">
    <PageHeader
      :title="`Directorio${records.length ? ` (${records.length})` : ''}`"
      subtitle="Preperfiles para invitar transportistas por WhatsApp o correo"
      :back="{ name: 'admin-carriers' }"
      back-label="Transportistas"
    >
      <template #actions>
        <button type="button" class="cc-btn-secondary w-auto px-3" :disabled="loading" @click="load">
          <RefreshCw class="size-4" :class="loading && 'animate-spin'" aria-hidden="true" />
          <span class="hidden sm:inline">Refrescar</span>
        </button>
        <button
          type="button"
          class="cc-btn-secondary w-auto px-3"
          :disabled="importing"
          @click="importDirectory"
        >
          <Download class="size-4" aria-hidden="true" />
          {{ importing ? 'Importando…' : 'Actualizar' }}
        </button>
        <RouterLink :to="{ name: 'admin-invitations' }" class="cc-btn w-auto px-4">
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
        subtitle="Importa el directorio de transportistas para comenzar a enviar invitaciones."
      >
        <template #icon><UserPlus /></template>
        <button type="button" class="cc-btn w-auto px-5" :disabled="importing" @click="importDirectory">
          <Download class="size-4" aria-hidden="true" />
          {{ importing ? 'Importando…' : 'Importar directorio' }}
        </button>
      </EmptyState>
    </div>

    <template v-else>
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
          <button type="button" class="cc-btn-secondary h-11 w-auto shrink-0 px-3 text-[13px]" @click="toggleAll">
            {{ allFilteredSelected ? 'Quitar' : 'Seleccionar' }}
          </button>
        </div>
      </div>

      <p v-if="!filtered.length" class="py-16 text-center text-sm text-muted">
        Sin resultados para “{{ search }}”
      </p>

      <ul v-else class="grid gap-2.5">
        <li v-for="record in filtered" :key="record.id">
          <button
            type="button"
            class="flex w-full items-start gap-3 rounded-2xl border p-3.5 text-left transition"
            :class="
              selected.has(record.id)
                ? 'border-brand/30 bg-blue-soft/50'
                : 'border-transparent bg-card shadow-card hover:shadow-card-hover'
            "
            @click="toggle(record.id)"
          >
            <span
              class="mt-0.5 flex size-6 shrink-0 items-center justify-center rounded-full border"
              :class="selected.has(record.id) ? 'border-brand bg-brand text-white' : 'border-line bg-card text-transparent'"
            >
              <Check class="size-3.5" aria-hidden="true" />
            </span>
            <span class="min-w-0 flex-1">
              <span class="flex items-start justify-between gap-3">
                <span class="truncate text-sm font-semibold text-navy">{{ record.companyName }}</span>
                <span class="cc-badge shrink-0" :class="statusOf(record.status).cls">
                  {{ statusOf(record.status).label }}
                </span>
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
          </button>
        </li>
      </ul>
    </template>

    <Teleport to="body">
    <div
      v-if="selected.size"
      class="fixed inset-x-0 bottom-[calc(4.5rem+env(safe-area-inset-bottom))] z-40 border-t border-line bg-card/95 px-4 py-3 shadow-elevated backdrop-blur md:bottom-0 md:left-[248px]"
    >
      <div class="mx-auto flex max-w-6xl items-center gap-3">
        <div class="min-w-0">
          <p class="text-sm font-semibold text-navy">
            {{ selected.size }} seleccionado{{ selected.size === 1 ? '' : 's' }}
          </p>
          <p class="text-[11px] text-muted">
            {{ selectedWithPhone.length }} WhatsApp · {{ selectedWithEmail.length }} correo
          </p>
        </div>
        <div class="ml-auto flex gap-2">
          <button
            type="button"
            class="cc-btn h-10 w-auto bg-[#3cbc54] px-3 shadow-none hover:bg-[#34a84a]"
            :disabled="!selectedWithPhone.length || sending"
            @click="send('whatsapp')"
          >
            <MessageCircle class="size-4" aria-hidden="true" />
            WA ({{ selectedWithPhone.length }})
          </button>
          <button
            type="button"
            class="cc-btn h-10 w-auto px-3"
            :disabled="!selectedWithEmail.length || sending"
            @click="send('email')"
          >
            <Mail class="size-4" aria-hidden="true" />
            Email ({{ selectedWithEmail.length }})
          </button>
        </div>
      </div>
    </div>
    </Teleport>
  </div>
</template>
