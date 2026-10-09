import './style.css';
import { createApp } from 'vue';
import { createPinia } from 'pinia';
import App from './App.vue';
import router from './plugins/router';
import { auth } from './plugins/firebase';
import { useAuthStore } from './stores/auth';

const app = createApp(App);
const pinia = createPinia();

app.use(pinia);

auth.authStateReady().then(async () => {
  const authStore = useAuthStore();
  await authStore.restoreSession();
  app.use(router);
  app.mount('#app');
});
