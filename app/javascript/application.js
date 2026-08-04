// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Trix/ActionText NO van aquí (Fase 16.5): solo blog/novedades del admin
// los usan — se cargan bajo demanda con javascript_import_module_tag
// "rich_text" desde esas vistas (~200KB fuera del resto de la app).

// PWA (Fase 14.1): service worker con shell precacheado y fallback offline.
// Solo navegación y /assets/ — no toca POST ni streams de Turbo.
if ("serviceWorker" in navigator) {
  addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js").catch(() => {})
  })
}
