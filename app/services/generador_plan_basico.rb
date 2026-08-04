# Plan de entrenamiento sugerido incluido con la membresía (SDD §03/§11,
# Fases 5.9/5.11). Sin IA: arma una rutina de fuerza de 6 días (lunes–sábado,
# domingo descanso) desde las plantillas de ejercicio, con reglas
# deterministas según el objetivo del miembro. Desde la Fase 14.8 la semana
# base forma un mesociclo v2 de 4 semanas con progresión lineal y descarga
# final. Recibe el User (+ objetivo) y devuelve el hash `rutina` con la misma
# forma que el plan de la IA.
module GeneradorPlanBasico
  DIAS = %w[lunes martes miercoles jueves viernes sabado].freeze

  # superavit → Push/Pull/Legs ×2 (hipertrofia)
  PPL = [
    [ "Empuje: pecho, hombro y tríceps", { pecho: 2, hombro: 1, triceps: 1 } ],
    [ "Jalón: espalda y bíceps",         { espalda: 2, biceps: 1, core: 1 } ],
    [ "Pierna y glúteo",                 { pierna: 2, gluteo: 1, core: 1 } ]
  ].freeze

  # deficit → full-body alterno A/B ×3 (conserva músculo en déficit)
  FULLBODY_AB = [
    [ "Cuerpo completo A", { pierna: 1, pecho: 1, espalda: 1, core: 1 } ],
    [ "Cuerpo completo B", { pierna: 1, hombro: 1, espalda: 1, gluteo: 1 } ]
  ].freeze

  # mantenimiento / sin objetivo → torso/pierna alterno
  TORSO_PIERNA = [
    [ "Torso: pecho, espalda y hombro", { pecho: 1, espalda: 1, hombro: 1, biceps: 1 } ],
    [ "Pierna y core",                  { pierna: 2, gluteo: 1, core: 1 } ]
  ].freeze

  # Énfasis del perfil femenino (Fase 14.16, Bloque D del plan): en cada
  # split, el día de pierna prioriza glúteo — la preferencia de entrenamiento
  # mayoritaria del público femenino del gimnasio. Es un DEFAULT del plan
  # sugerido, no un candado: la miembro lo edita como cualquier plan por
  # reglas. El volumen total del día no cambia (mismos 4-5 ejercicios).
  ENFASIS_F = {
    "Pierna y glúteo" => [ "Glúteo y pierna", { gluteo: 2, pierna: 1, core: 1 } ],
    "Pierna y core"   => [ "Glúteo, pierna y core", { gluteo: 2, pierna: 1, core: 1 } ],
    "Cuerpo completo A" => [ "Cuerpo completo A", { pierna: 1, gluteo: 1, espalda: 1, core: 1 } ]
  }.freeze

  def self.para(user, objetivo: nil)
    objetivo ||= user.objetivo_activo if user.respond_to?(:objetivo_activo) && user.persisted?
    biblioteca = PlantillaEjercicio.ordenadas.group_by(&:musculo)
    plantilla_semana = segun_objetivo(objetivo&.tipo)
    plantilla_semana = con_enfasis_femenino(plantilla_semana) if user.respond_to?(:sexo) && user.sexo == "F"

    dias = DIAS.each_with_index.map do |dia, indice|
      enfoque, receta = plantilla_semana[indice % plantilla_semana.size]
      # El offset rota los ejercicios entre repeticiones del mismo enfoque para
      # variar la semana (p. ej. Empuje del lunes ≠ Empuje del jueves).
      dia_desde(dia, enfoque, receta, biblioteca, offset: indice / plantilla_semana.size)
    end
    # Mesociclo v2 (Fase 14.8): la semana base + la progresión lineal
    # determinista de 4 semanas (1.00/1.05/1.10/0.85, la última descarga).
    progresion = Ejercicios::ValidadorRutina.progresion_defecto
    { "version" => 2, "mesociclo" => progresion["mesociclo"],
      "dias" => dias, "semanas" => progresion["semanas"] }
  end

  def self.segun_objetivo(tipo)
    case tipo
    when "superavit" then PPL
    when "deficit" then FULLBODY_AB
    else TORSO_PIERNA
    end
  end

  def self.con_enfasis_femenino(plantilla_semana)
    plantilla_semana.map { |enfoque, receta| ENFASIS_F.fetch(enfoque, [ enfoque, receta ]) }
  end

  def self.dia_desde(dia, enfoque, receta, biblioteca, offset:)
    ejercicios = receta.flat_map do |musculo, cantidad|
      disponibles = Array(biblioteca[musculo.to_s])
      next [] if disponibles.empty?

      cantidad.times.map { |k| ejercicio_hash(disponibles[(offset + k) % disponibles.size]) }
    end
    { "dia" => dia, "enfoque" => enfoque, "ejercicios" => ejercicios }
  end

  def self.ejercicio_hash(plantilla)
    # uid (Fase 14.6): identidad estable por entrada — el seguimiento se ancla
    # a él, no a la posición en el array.
    { "nombre" => plantilla.nombre, "series" => plantilla.series || 3,
      "repeticiones" => plantilla.repeticiones, "descanso_seg" => plantilla.descanso_seg || 60,
      "ejercicio_id" => plantilla.ejercicio_id,
      "uid" => SecureRandom.alphanumeric(10) }.compact
  end
end
