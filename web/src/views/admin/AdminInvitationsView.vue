<script setup lang="ts">
import { onMounted, onUnmounted, reactive, ref } from 'vue';
import {
  addDoc,
  collection,
  onSnapshot,
  type Unsubscribe,
} from 'firebase/firestore';
import { Send, MailPlus, Phone, Mail } from '@lucide/vue';
import { db } from '@/plugins/firebase';
import { initials, timeAgo } from '@/lib/format';
import { toast } from '@/lib/toast';
import PageHeader from '@/components/PageHeader.vue';

interface Invitation {
  id: string;
  name: string;
  phone?: string;
  email?: string;
  status: string;
  createdAt: Date;
}

const form = reactive({ name: '', phone: '', email: '' });
const sending = ref(false);
const loaded = ref(false);
const invitations = ref<Invitation[]>([]);
let unsub: Unsubscribe | null = null;

const statusLabels: Record<string, { label: string; cls: string }> = {
  sent: { label: 'Enviada', cls: 'bg-blue-soft text-blue-ink' },
  accepted: { label: 'Aceptada', cls: 'bg-success-soft text-success' },
  expired: { label: 'Vencida', cls: 'bg-slate-100 text-slate-600' },
};

onMounted(() => {
  unsub = onSnapshot(
    collection(db, 'invitations'),
    (snap) => {
      loaded.value = true;
      invitations.value = snap.docs
        .map((d) => {
          const data = d.data();
          return {
            id: d.id,
            name: String(data.name ?? ''),
            phone: data.phone ? String(data.phone) : undefined,
            email: data.email ? String(data.email) : undefined,
            status: String(data.status ?? 'sent'),
            createdAt:
              typeof data.createdAt?.toDate === 'function'
                ? data.createdAt.toDate()
                : new Date(),
          };
        })
        .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
    },
    () => {
      loaded.value = true;
    },
  );
});

onUnmounted(() => unsub?.());

async function send() {
  if (!form.name.trim() || (!form.phone && !form.email)) {
    toast.error('Faltan datos', 'Escribe el nombre y un teléfono o correo.');
    return;
  }
  sending.value = true;
  try {
    await addDoc(collection(db, 'invitations'), {
      name: form.name,
      phone: form.phone || '',
      email: form.email || '',
      status: 'sent',
      createdAt: new Date(),
    });
    toast.success('Invitación enviada', form.name);
    form.name = '';
    form.phone = '';
    form.email = '';
  } catch (e) {
    toast.error('No se pudo enviar', e instanceof Error ? e.message : undefined);
  } finally {
    sending.value = false;
  }
}
</script>

<template>
  <div class="cc-page">
    <PageHeader
      title="Invitaciones"
      subtitle="Invita transportistas a registrarse en Continente Conecta"
      :back="{ name: 'admin-carriers' }"
      back-label="Transportistas"
    />

    <div class="grid gap-5 lg:grid-cols-[minmax(0,400px)_minmax(0,1fr)] lg:items-start">
      <form class="cc-card overflow-hidden" @submit.prevent="send">
        <div class="flex items-center gap-3 border-b border-line bg-background/50 px-5 py-4">
          <span class="cc-icon-tile size-9"><MailPlus class="size-[18px]" aria-hidden="true" /></span>
          <div>
            <h2 class="cc-h2">Nueva invitación</h2>
            <p class="text-xs text-muted">Recibirá un enlace para registrarse</p>
          </div>
        </div>
        <div class="space-y-4 p-5">
          <div>
            <label class="cc-label" for="inv-name">Nombre o empresa</label>
            <input id="inv-name" v-model="form.name" class="cc-field" placeholder="Transportes del Norte" required />
          </div>
          <div>
            <label class="cc-label" for="inv-phone">Teléfono (WhatsApp)</label>
            <input id="inv-phone" v-model="form.phone" type="tel" class="cc-field" placeholder="81 1234 5678" />
          </div>
          <div>
            <label class="cc-label" for="inv-email">Correo</label>
            <input id="inv-email" v-model="form.email" type="email" class="cc-field" placeholder="trafico@empresa.mx" />
            <p class="cc-hint">Se requiere teléfono o correo.</p>
          </div>
          <button type="submit" class="cc-btn" :disabled="sending">
            <Send class="size-4" aria-hidden="true" />
            {{ sending ? 'Enviando…' : 'Enviar invitación' }}
          </button>
        </div>
      </form>

      <section class="min-w-0">
        <div class="mb-3 flex items-center justify-between">
          <h2 class="cc-h2">Enviadas</h2>
          <span class="text-xs font-medium text-muted">{{ invitations.length }}</span>
        </div>
        <div v-if="!loaded" class="cc-card space-y-3 p-4">
          <div v-for="i in 3" :key="i" class="flex items-center gap-3">
            <div class="cc-skeleton size-9 rounded-full" />
            <div class="flex-1 space-y-1.5">
              <div class="cc-skeleton h-3.5 w-1/2" />
              <div class="cc-skeleton h-3 w-1/3" />
            </div>
          </div>
        </div>
        <div v-else-if="!invitations.length" class="rounded-2xl border border-dashed border-line px-6 py-12 text-center">
          <MailPlus class="mx-auto size-6 text-muted" aria-hidden="true" />
          <p class="mt-3 text-sm font-semibold text-navy">Aún no has enviado invitaciones</p>
        </div>
        <ul v-else class="cc-card divide-y divide-line overflow-hidden">
          <li v-for="i in invitations" :key="i.id" class="flex items-center gap-3 px-4 py-3.5">
            <span class="flex size-9 shrink-0 items-center justify-center rounded-full bg-navy/[0.07] text-[12px] font-bold text-navy">
              {{ initials(i.name) }}
            </span>
            <div class="min-w-0 flex-1">
              <p class="truncate text-sm font-semibold text-navy">{{ i.name }}</p>
              <p class="mt-0.5 flex items-center gap-1.5 truncate text-xs text-muted">
                <component :is="i.phone ? Phone : Mail" class="size-3 shrink-0" aria-hidden="true" />
                {{ i.phone || i.email }} · {{ timeAgo(i.createdAt) }}
              </p>
            </div>
            <span class="cc-badge" :class="(statusLabels[i.status] ?? statusLabels.sent).cls">
              {{ (statusLabels[i.status] ?? { label: i.status }).label }}
            </span>
          </li>
        </ul>
      </section>
    </div>
  </div>
</template>
