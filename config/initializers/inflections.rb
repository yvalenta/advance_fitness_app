# Be sure to restart your server when you modify this file.

# Plurales del dominio en español (SDD §12). Sin esto, el inflector
# inglés rompe palabras como "membresia" (la regla latina -ia la trata
# como plural invariable) o "plan" (→ "plans").
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular "membresia", "membresias"
  inflect.irregular "pago", "pagos"
  inflect.irregular "acceso", "accesos"
  inflect.irregular "medicion", "mediciones"
  inflect.irregular "objetivo_nutricional", "objetivos_nutricionales"
  inflect.irregular "registro_caloria", "registros_calorias"
  inflect.irregular "registro_entrenamiento", "registros_entrenamiento"
  inflect.irregular "plan", "planes"
  inflect.irregular "suscripcion", "suscripciones"
  inflect.irregular "plan_personalizado", "planes_personalizados"
  inflect.irregular "novedad", "novedades"
  inflect.irregular "renovacion", "renovaciones"
  inflect.irregular "borrador", "borradores"
  inflect.irregular "aprobacion", "aprobaciones"
  inflect.irregular "plantilla_comida", "plantillas_comida"
  inflect.irregular "plantilla_ejercicio", "plantillas_ejercicio"
  inflect.irregular "consentimiento", "consentimientos"
  # Motor de juego (Fase 14.12). Sin estos, Zeitwerk no resuelve los modelos:
  # el inflector inglés pluraliza solo la última palabra ("registro_puntos").
  # "logro"/"logros" y "racha"/"rachas" sí funcionan con la regla default.
  inflect.irregular "registro_punto", "registros_puntos"
  inflect.irregular "perfil_juego", "perfiles_juego"
  inflect.irregular "logro_obtenido", "logros_obtenidos"
  # Récords personales (Fase 14.13): mismo motivo — el inflector inglés
  # daría "record_personals" y Zeitwerk no resolvería el modelo.
  inflect.irregular "record_personal", "records_personales"
  # Ciclo menstrual (Fase 14.15): ídem — el inflector daría "ciclo_menstruals".
  inflect.irregular "ciclo_menstrual", "ciclos_menstruales"
  # Web Push (Fase 15): el inflector daría "suscripcion_pushes".
  inflect.irregular "suscripcion_push", "suscripciones_push"
  # Autoservicio (Fase 12a, §17.5): el inflector daría "solicitud_autoservicios".
  inflect.irregular "solicitud_autoservicio", "solicitudes_autoservicio"
  # Reprogramar un día (Fase 19e): el inflector daría "reprogramacion_dias".
  inflect.irregular "reprogramacion_dia", "reprogramaciones_dia"
  # Cambio de organización (tarea 2026-08-31): el inflector daría
  # "cambio_organizacions". "puesto"/"puestos" funciona con la regla default.
  inflect.irregular "cambio_organizacion", "cambios_organizacion"
end
