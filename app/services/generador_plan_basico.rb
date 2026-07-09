# Plan básico de entrenamiento incluido con la membresía (SDD §03/§11, Fase
# 5.9). Sin IA: arma una rutina de fuerza desde las plantillas de ejercicio
# sembradas, con reglas simples y deterministas. PORO puro (sin sesión ni
# escritura): recibe un User y devuelve un hash `rutina` con la misma forma que
# el plan de la IA, para reusar el partial de rutina de solo lectura.
module GeneradorPlanBasico
  # Principiantes o mayores → full-body 3 días; el resto → split de 4 días.
  DIAS_FULLBODY = %w[lunes miercoles viernes].freeze
  FULLBODY = { pierna: 1, pecho: 1, espalda: 1, hombro: 1, core: 1 }.freeze

  SPLIT_4 = [
    [ "lunes",   "Pecho y tríceps",  { pecho: 2, triceps: 1, hombro: 1 } ],
    [ "martes",  "Espalda y bíceps", { espalda: 2, biceps: 1, core: 1 } ],
    [ "jueves",  "Pierna y glúteo",  { pierna: 2, gluteo: 1, core: 1 } ],
    [ "viernes", "Hombro y brazos",  { hombro: 2, triceps: 1, biceps: 1 } ]
  ].freeze

  def self.para(user)
    biblioteca = PlantillaEjercicio.ordenadas.group_by(&:musculo)
    dias =
      if fullbody?(user)
        DIAS_FULLBODY.each_with_index.map { |dia, i| dia_desde(dia, "Cuerpo completo", FULLBODY, biblioteca, offset: i) }
      else
        SPLIT_4.map { |dia, enfoque, receta| dia_desde(dia, enfoque, receta, biblioteca, offset: 0) }
      end
    { "dias" => dias }
  end

  # Sin edad conocida o desde los 50, se prioriza una rutina más conservadora.
  def self.fullbody?(user)
    edad = user.edad
    edad.nil? || edad >= 50
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
    { "nombre" => plantilla.nombre, "series" => plantilla.series || 3,
      "repeticiones" => plantilla.repeticiones, "descanso_seg" => plantilla.descanso_seg || 60 }
  end
end
