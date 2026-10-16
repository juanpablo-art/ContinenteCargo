import { onMounted, onUnmounted, ref } from 'vue';

const now = ref(Date.now());
let timer: number | undefined;
let users = 0;

/** One shared second tick for every running counter on screen. */
export function useNow() {
  onMounted(() => {
    users += 1;
    now.value = Date.now();
    if (timer == null) {
      timer = window.setInterval(() => {
        now.value = Date.now();
      }, 1000);
    }
  });
  onUnmounted(() => {
    users = Math.max(0, users - 1);
    if (users === 0 && timer != null) {
      window.clearInterval(timer);
      timer = undefined;
    }
  });
  return now;
}

function pad(value: number) {
  return String(value).padStart(2, '0');
}

/** Elapsed time since publication, ticking as HH:MM:SS (and days when it passes 24 h). */
export function formatElapsed(since: Date, nowMs: number): string {
  const start = since instanceof Date && !Number.isNaN(since.getTime()) ? since.getTime() : nowMs;
  const total = Math.max(0, Math.floor((nowMs - start) / 1000));
  const days = Math.floor(total / 86400);
  const hours = Math.floor((total % 86400) / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const seconds = total % 60;
  const clock = `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
  return days > 0 ? `${days}d ${clock}` : clock;
}
