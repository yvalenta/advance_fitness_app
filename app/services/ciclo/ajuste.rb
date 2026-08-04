module Ciclo
  # Traduce la fase derivada (Ciclo::Fase) a un ajuste sugerido con el MISMO
  # shape del ajuste de mesociclo — {"series_delta", "peso_factor",
  # "reps_delta"} — más "kcal_delta" y un "mensaje" amable para la card. La
  # composición con el mesociclo la hace otro módulo; aquí solo se expone el
  # shape.
  #
  # REGLA DURA (blindada property-style en specs): la fase solo BAJA la
  # carga o la deja igual — jamás la sube. Ningún peso_factor > 1.0, ningún
  # delta de series/reps positivo. Los días de más energía se comunican con
  # el mensaje, no cargando la barra por decreto.
  module Ajuste
    # Identidad: no cambia nada. Es el ajuste de :desconocida — sin
    # consentimiento o sin datos, el módulo es invisible para el plan.
    NULO = {
      "series_delta" => 0,
      "peso_factor" => 1.0,
      "reps_delta" => 0,
      "kcal_delta" => 0,
      "mensaje" => nil
    }.freeze

    POR_FASE = {
      menstrual: NULO.merge(
        "series_delta" => -1,
        "peso_factor" => 0.85,
        "mensaje" => "Días para escucharte: baja un poco la carga y quédate con lo que se sienta bien. Moverte suave también cuenta."
      ).freeze,
      folicular: NULO.merge(
        "mensaje" => "Energía en ascenso: buen momento para entrenar con ganas y buscar pequeños récords."
      ).freeze,
      ovulacion: NULO.merge(
        "mensaje" => "Pico de energía: aprovecha tus sesiones más exigentes, sin descuidar la técnica."
      ).freeze,
      # La bajada del 0.9 corresponde a la lútea tardía; como la fase se
      # deriva sin subdividir, se aplica a toda la lútea — conservador, y
      # consistente con la regla de solo bajar.
      lutea: NULO.merge(
        "peso_factor" => 0.9,
        "kcal_delta" => 150,
        "mensaje" => "Tu cuerpo trabaja extra estos días: afloja un poco la intensidad, y si el hambre sube no te preocupes — es normal."
      ).freeze,
      desconocida: NULO
    }.freeze

    def self.para(fase)
      POR_FASE.fetch(fase.to_s.to_sym, NULO)
    end
  end
end
