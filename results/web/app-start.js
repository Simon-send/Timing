// Retire only the legacy Flutter worker/caches for this application.
let startupContinued = false;
async function retireFlutterCache() {
  if (!('serviceWorker' in navigator)) return;
  const root = new URL('.', document.baseURI);
  const isFlutter = worker => worker && new URL(worker.scriptURL).origin === root.origin &&
    new URL(worker.scriptURL).pathname === root.pathname + 'flutter_service_worker.js';
  const registrations = await navigator.serviceWorker.getRegistrations();
  for (const registration of registrations) {
    if (registration.scope === root.href &&
        [registration.active, registration.waiting, registration.installing].some(isFlutter)) {
      await registration.unregister();
      for (const name of ['flutter-app-cache', 'flutter-temp-cache', 'flutter-app-manifest']) {
        await caches.delete(name);
      }
    }
  }
  if (!startupContinued && isFlutter(navigator.serviceWorker.controller)) {
    const key = 'plotting-worker-retired-v1';
    if (!sessionStorage.getItem(key)) {
      sessionStorage.setItem(key, '1');
      location.reload();
      return;
    }
  }
}
Promise.race([
  retireFlutterCache().catch(() => console.warn('Legacy cache cleanup unavailable')),
  new Promise(resolve => setTimeout(resolve, 3000)),
]).finally(() => {
  startupContinued = true;
  const script = document.createElement('script');
  script.src = 'flutter_bootstrap.js';
  script.async = true;
  document.body.appendChild(script);
});
