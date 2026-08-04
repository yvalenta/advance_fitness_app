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
    reps = repeticiones.to_s[/\d+/].to_i
    reps = 1 if reps < 1
    siguiente = registro.detalles.where(ejercicio: ejercicio).maximum(:serie).to_i
    series.to_i.times.map do |i|
      registro.detalles.create!(ejercicio: ejercicio, serie: siguiente + i + 1,
                                repeticiones: reps, peso_kg: peso_kg.presence)
    end
  end
end
