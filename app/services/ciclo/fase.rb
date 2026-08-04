module Ciclo
  # Deriva la fase del ciclo a partir de los inicios registrados — NUNCA la
  # persiste (mismo principio que User#edad: lo derivable no se guarda, así
  # no hay una columna sensible extra que proteger ni que quede obsoleta).
  #
  # Fail-closed: sin consentimiento `ciclo_menstrual` vigente o sin datos,
  # la respuesta es :desconocida y el resto del sistema se comporta como si
  # el módulo no existiera (Ciclo::Ajuste.para(:desconocida) es identidad).
  module Fase
    FASES = %i[menstrual folicular ovulacion lutea desconocida].freeze

    DURACION_DEFAULT = 28   # largo de ciclo cuando no hay historial suficiente
    SANGRADO_DEFAULT = 5    # días de fase menstrual si no se registró duración
    LUTEA_DIAS = 14         # la fase lútea dura ~14 días sea cual sea el ciclo
    VENTANA_OVULACION = 1   # ± días alrededor del día estimado de ovulación
    RETRASO_TOLERADO = 7    # pasado el largo estimado + esto, ya no se estima
    GAP_VEROSIMIL = 21..45  # separaciones entre inicios que cuentan al promedio

    # → :menstrual | :folicular | :ovulacion | :lutea | :desconocida
    def self.para(user, fecha = Date.current)
      dia = dia_del_ciclo(user, fecha)
      return :desconocida unless dia

      largo = duracion_estimada(user, fecha)
      return :desconocida if dia > largo + RETRASO_TOLERADO

      sangrado = ultimo_ciclo(user, fecha).duracion_sangrado_dias || SANGRADO_DEFAULT
      dia_ovulacion = largo - LUTEA_DIAS

      if dia <= sangrado
        :menstrual
      elsif dia < dia_ovulacion - VENTANA_OVULACION
        :folicular
      elsif dia <= dia_ovulacion + VENTANA_OVULACION
        :ovulacion
      else
        :lutea
      end
    end

    # Fecha estimada del próximo inicio (último inicio + largo estimado), o
    # nil sin consentimiento/datos. Puede caer en el pasado — la UI lo lee
    # como "con unos días de retraso", no como error.
    def self.proxima_menstruacion(user, fecha = Date.current)
      ultimo = ultimo_con_consentimiento(user, fecha)
      return nil unless ultimo

      ultimo.fecha_inicio + duracion_estimada(user, fecha)
    end

    # Día del ciclo en curso (1 = primer día de sangrado), o nil.
    def self.dia_del_ciclo(user, fecha = Date.current)
      ultimo = ultimo_con_consentimiento(user, fecha)
      return nil unless ultimo

      (fecha - ultimo.fecha_inicio).to_i + 1
    end

    # Largo estimado: promedio de las separaciones entre los últimos 4
    # inicios (3 gaps). Los gaps inverosímiles (meses sin registrar, dobles
    # registros) no cuentan; sin gaps útiles se asume DURACION_DEFAULT.
    def self.duracion_estimada(user, fecha = Date.current)
      inicios = user.ciclos_menstruales.where(fecha_inicio: ..fecha)
                    .order(fecha_inicio: :desc).limit(4).pluck(:fecha_inicio)
      gaps = inicios.each_cons(2)
                    .map { |reciente, anterior| (reciente - anterior).to_i }
                    .select { |gap| GAP_VEROSIMIL.cover?(gap) }
      return DURACION_DEFAULT if gaps.empty?

      (gaps.sum.to_f / gaps.size).round
    end

    def self.ultimo_con_consentimiento(user, fecha)
      return nil unless Consentimiento.vigente?(user, "ciclo_menstrual")

      ultimo_ciclo(user, fecha)
    end
    private_class_method :ultimo_con_consentimiento

    def self.ultimo_ciclo(user, fecha)
      user.ciclos_menstruales.where(fecha_inicio: ..fecha).order(:fecha_inicio).last
    end
    private_class_method :ultimo_ciclo
  end
end
