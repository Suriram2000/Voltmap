{{flutter_js}}
{{flutter_build_config}}

async function removeLegacyFlutterWebCache() {
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
}

(async () => {
  try {
    await removeLegacyFlutterWebCache();
  } catch (error) {
    console.warn('Unable to remove the legacy Flutter web cache.', error);
  }

  await _flutter.loader.load();
})();
