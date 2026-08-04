// Service worker (Fase 14.1): shell mínimo precacheado + página offline.
// - Navegación (GET, mode "navigate"): network-first, fallback a /offline.html.
// - /assets/ (fingerprinted, inmutables) e íconos del shell: cache-first.
// - Nada más se intercepta: POST, turbo_stream, cable y el proxy de media
//   pasan directo a la red — Turbo no se entera de que existimos.
const VERSION = "advance-v1"
const SHELL = ["/offline.html", "/icon.png", "/icon-192.png", "/icon.svg"]

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(VERSION)
      .then((cache) => cache.addAll(SHELL))
      .then(() => self.skipWaiting())
  )
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((claves) => Promise.all(claves.filter((clave) => clave !== VERSION).map((clave) => caches.delete(clave))))
      .then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", (event) => {
  const { request } = event
  if (request.method !== "GET") return

  // Navegación: red primero (el contenido vive en el servidor); sin red,
  // la página offline precacheada.
  if (request.mode === "navigate") {
    event.respondWith(fetch(request).catch(() => caches.match("/offline.html")))
    return
  }

  const url = new URL(request.url)
  const cacheable = url.origin === self.location.origin &&
    (url.pathname.startsWith("/assets/") || SHELL.includes(url.pathname))
  if (!cacheable) return

  event.respondWith(
    caches.match(request).then((guardada) =>
      guardada || fetch(request).then((respuesta) => {
        if (respuesta.ok) {
          const copia = respuesta.clone()
          caches.open(VERSION).then((cache) => cache.put(request, copia))
        }
        return respuesta
      })
    )
  )
})
