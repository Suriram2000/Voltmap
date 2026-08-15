{{flutter_js}}
{{flutter_build_config}}

let deferredVoltMapEVInstallPrompt = null;

function voltMapEVIsInstalled() {
  return window.matchMedia('(display-mode: standalone)').matches ||
    window.navigator.standalone === true;
}

function voltMapEVPlatform() {
  const userAgent = window.navigator.userAgent.toLowerCase();
  const iPadOS = window.navigator.platform === 'MacIntel' &&
    window.navigator.maxTouchPoints > 1;
  if (/iphone|ipad|ipod/.test(userAgent) || iPadOS) return 'ios';
  if (userAgent.includes('android')) return 'android';
  return 'desktop';
}

window.addEventListener('beforeinstallprompt', (event) => {
  event.preventDefault();
  deferredVoltMapEVInstallPrompt = event;
  window.dispatchEvent(new Event('voltmapev-install-available'));
});

window.addEventListener('appinstalled', () => {
  deferredVoltMapEVInstallPrompt = null;
  window.dispatchEvent(new Event('voltmapev-install-complete'));
});

window.voltMapEVInstallStatus = () => JSON.stringify({
  platform: voltMapEVPlatform(),
  installed: voltMapEVIsInstalled(),
  canPrompt: deferredVoltMapEVInstallPrompt !== null,
});

window.voltMapEVPromptInstall = async () => {
  if (voltMapEVIsInstalled()) return 'accepted';
  if (deferredVoltMapEVInstallPrompt === null) return 'unavailable';
  const prompt = deferredVoltMapEVInstallPrompt;
  deferredVoltMapEVInstallPrompt = null;
  await prompt.prompt();
  const choice = await prompt.userChoice;
  return choice.outcome === 'accepted' ? 'accepted' : 'dismissed';
};

async function removeLegacyFlutterWebCache() {
  const resetKey = 'voltmapev-pwa-cache-reset-v2';
  if (window.localStorage.getItem(resetKey) === 'done') return;
  if ('serviceWorker' in navigator) {
    const registrations = await navigator.serviceWorker.getRegistrations();
    await Promise.all(
      registrations.map((registration) => registration.unregister()),
    );
  }

  if ('caches' in window) {
    const cacheNames = await caches.keys();
    await Promise.all(
      cacheNames
        .filter((name) => name.startsWith('flutter-'))
        .map((name) => caches.delete(name)),
    );
  }
  window.localStorage.setItem(resetKey, 'done');
}

removeLegacyFlutterWebCache().catch((error) => {
  console.warn('Unable to remove the legacy Flutter web cache.', error);
});

_flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => {
        const splash = document.getElementById('boot-splash');
        if (splash === null) return;
        splash.classList.add('is-ready');
        window.setTimeout(() => splash.remove(), 180);
      });
    });
  },
});
