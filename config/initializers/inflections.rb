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
end
