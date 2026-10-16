import { computed, onMounted, onUnmounted, ref } from 'vue';

/** Keeps a fixed action above the tab bar, and above the keyboard while typing. */
export function useMobileActionBar() {
  const isDesktop = ref(false);
  const keyboardInset = ref(0);

  function sync() {
    isDesktop.value = window.matchMedia('(min-width: 768px)').matches;
    const viewport = window.visualViewport;
    const active = document.activeElement;
    const editing =
      active instanceof HTMLInputElement ||
      active instanceof HTMLTextAreaElement ||
      active instanceof HTMLSelectElement;
    if (!viewport || isDesktop.value || !editing) {
      keyboardInset.value = 0;
      return;
    }
    const covered = window.innerHeight - viewport.height - viewport.offsetTop;
    keyboardInset.value = covered > 120 ? covered : 0;
  }

  const style = computed<Record<string, string>>(() => {
    if (isDesktop.value) return { left: '248px', right: '0px', bottom: '0px' };
    if (keyboardInset.value > 0) {
      return { left: '0px', right: '0px', bottom: `${keyboardInset.value}px` };
    }
    return {
      left: '0px',
      right: '0px',
      bottom: 'calc(4.5rem + env(safe-area-inset-bottom))',
    };
  });

  onMounted(() => {
    sync();
    window.addEventListener('resize', sync);
    window.addEventListener('focusin', sync);
    window.addEventListener('focusout', sync);
    window.visualViewport?.addEventListener('resize', sync);
    window.visualViewport?.addEventListener('scroll', sync);
  });

  onUnmounted(() => {
    window.removeEventListener('resize', sync);
    window.removeEventListener('focusin', sync);
    window.removeEventListener('focusout', sync);
    window.visualViewport?.removeEventListener('resize', sync);
    window.visualViewport?.removeEventListener('scroll', sync);
  });

  return { style, keyboardInset, isDesktop };
}
