# Una serie ejecutada de un ejercicio dentro de una sesión de entrenamiento.
# Es el dato cuantitativo que alimenta la IA analítica (SDD §18): volumen de
# carga, récords personales y detección de estancamiento.
class DetalleEntrenamiento < ApplicationRecord
  belongs_to :registro_entrenamiento
  belongs_to :ejercicio

  validates :serie, :repeticiones, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :peso_kg, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :rpe, numericality: { only_integer: true, in: 1..10 }, allow_nil: true
  validates :serie, uniqueness: { scope: [ :registro_entrenamiento_id, :ejercicio_id ] }

  # Volumen de carga de la serie; peso_kg nulo (peso corporal) aporta 0 —
  # el volumen mide carga externa, no esfuerzo total.
  def volumen_kg
    repeticiones * (peso_kg || 0)
  end

  # "La vez pasada" (Fase 14.2): la última serie registrada de cada ejercicio
  # en fechas anteriores a `antes_de`, en UNA sola query (DISTINCT ON toma la
  # serie más alta de la sesión más reciente). Devuelve {ejercicio_id => detalle}
  # para que la rutina lo muestre sin N+1.
  def self.ultimos_por_ejercicio(user, ejercicio_ids, antes_de: Date.current)
    return {} if ejercicio_ids.blank?

    joins(:registro_entrenamiento)
      .where(registros_entrenamiento: { user_id: user.id, fecha: ...antes_de })
      .where(ejercicio_id: ejercicio_ids.uniq)
      .select("DISTINCT ON (ejercicio_id) detalle_entrenamientos.*")
      .order("ejercicio_id, registros_entrenamiento.fecha DESC, serie DESC")
      .index_by(&:ejercicio_id)
  end

  # Mejor serie de cada ejercicio para estimar el 1RM (CalculadoraUnaRepMax,
  # fórmula de Epley): la de mayor 1RM estimado entre 1-12 reps con peso
  # externo — no basta con "el peso más alto", una serie de menos peso y más
  # reps puede estimar más. Misma técnica DISTINCT ON de ultimos_por_ejercicio.
  def self.mejores_sets_para_una_rm(user, ejercicio_ids = nil)
    scope = joins(:registro_entrenamiento)
              .where(registro_entrenamiento: { user_id: user.id })
              .where.not(peso_kg: nil)
              .where(repeticiones: 1..CalculadoraUnaRepMax::REPS_MAXIMAS)
    scope = scope.where(ejercicio_id: ejercicio_ids.uniq) if ejercicio_ids.present?

    scope.select("DISTINCT ON (ejercicio_id) detalle_entrenamientos.*")
         .order(Arel.sql("ejercicio_id, peso_kg * (1 + repeticiones / 30.0) DESC"))
  end

  # Resuelve el Ejercicio real para registrar una serie: por id (rutinas
  # nuevas) o por nombre contra el catálogo (fallback para rutinas viejas
  # sin ejercicio_id en su JSON, mismo criterio de Ejercicio.buscar_por_nombre
  # que ya usa EjerciciosController#ayuda). nil si no hay match.
  def self.ejercicio_para(ejercicio_id:, nombre:)
    Ejercicio.find_by(id: ejercicio_id) || Ejercicio.buscar_por_nombre(nombre)
  end

  # Captura rápida (Fase 12): "cumplido tal cual" registra de una sola vez
  # las `series` planeadas con el mismo objetivo de reps/peso, en vez de
  # pedir cada serie una por una — pensado para el celular. `repeticiones`
  # puede venir como rango del plan ("8-10"): se toma el número menor como
  # valor conservador registrado.
  def self.registrar_cumplido!(registro:, ejercicio:, series:, repeticiones:, peso_kg:)
    # Idempotente (Fase 18k, bug reportado con captura: 18 filas de un plan
    # de 3): cada reenvío "cumplido" apilaba otras N series. Con series ya
    # registradas no crea nada — corregir es quitar/añadir series a mano.
    return [] if registro.detalles.where(ejercicio: ejercicio).exists?

    reps = repeticiones.to_s[/\d+/].to_i
    reps = 1 if reps < 1
    series.to_i.times.map do |i|
      registro.detalles.create!(ejercicio: ejercicio, serie: i + 1,
                                repeticiones: reps, peso_kg: peso_kg.presence)
    end
  end
end
