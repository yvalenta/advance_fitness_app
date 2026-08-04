# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
# preload: false (Fase 16.5): con lazyLoadControllersFrom, el modulepreload
# del importmap descargaría los 21 controllers en toda página igual — sin
# esto el lazy no ahorra ni un byte.
pin_all_from "app/javascript/controllers", under: "controllers", preload: false
# Editor de texto enriquecido: SOLO lo usan blog/novedades del admin — va
# bajo demanda vía content_for :head (rich_text.js), nunca en el bundle global.
pin "rich_text", preload: false
pin "trix", preload: false
pin "@rails/actiontext", to: "actiontext.esm.js", preload: false
