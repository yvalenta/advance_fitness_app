// Carga PEREZOSA de controllers (Fase 16.5): cada uno se descarga la primera
// vez que su data-controller aparece en el DOM — el dashboard usa 2 de los
// 21. Requiere preload: false en el pin_all_from (config/importmap.rb) o el
// modulepreload los bajaría todos igual.
import { application } from "controllers/application"
import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
lazyLoadControllersFrom("controllers", application)
