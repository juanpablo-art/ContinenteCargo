<script setup lang="ts">
import { onMounted, onUnmounted, reactive, ref } from 'vue';
import {
  addDoc,
  collection,
  onSnapshot,
  type Unsubscribe,
} from 'firebase/firestore';
import { db } from '@/plugins/firebase';
import { formatDateTime } from '@/lib/format';

interface Invitation {
  id: string;
  name: string;
  phone?: string;
  email?: string;
  status: string;
  createdAt: Date;
}

const form = reactive({ name: '', phone: '', email: '' });
const msg = ref('');
const invitations = ref<Invitation[]>([]);
let unsub: Unsubscribe | null = null;

onMounted(() => {
  unsub = onSnapshot(collection(db, 'invitations'), (snap) => {
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
  });
});

onUnmounted(() => unsub?.());

async function send() {
  if (!form.name.trim() || (!form.phone && !form.email)) {
    msg.value = 'Nombre y teléfono o email requeridos';
    return;
  }
  await addDoc(collection(db, 'invitations'), {
    name: form.name,
    phone: form.phone || '',
    email: form.email || '',
    status: 'sent',
    createdAt: new Date(),
  });
  form.name = '';
  form.phone = '';
  form.email = '';
  msg.value = 'Invitación registrada';
}
</script>

<template>
  <div class="mx-auto w-full max-w-2xl px-4 py-6 sm:px-6">
    <h1 class="text-2xl font-bold text-navy">Invitaciones</h1>
    <form class="mt-5 space-y-3 rounded-2xl border border-line bg-card p-4" @submit.prevent="send">
      <input v-model="form.name" class="cc-field" placeholder="Nombre" required />
      <input v-model="form.phone" class="cc-field" placeholder="Teléfono" />
      <input v-model="form.email" type="email" class="cc-field" placeholder="Email" />
      <p v-if="msg" class="text-sm text-muted">{{ msg }}</p>
      <button type="submit" class="cc-btn">Enviar invitación</button>
    </form>
    <ul class="mt-6 space-y-2">
      <li
        v-for="i in invitations"
        :key="i.id"
        class="rounded-xl border border-line bg-card px-3 py-2 text-sm"
      >
        <p class="font-medium text-navy">{{ i.name }}</p>
        <p class="text-xs text-muted">
          {{ i.phone || i.email }} · {{ i.status }} · {{ formatDateTime(i.createdAt) }}
        </p>
      </li>
    </ul>
  </div>
</template>
