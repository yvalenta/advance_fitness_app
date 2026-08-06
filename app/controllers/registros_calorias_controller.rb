class RegistrosCaloriasController < ApplicationController
  before_action { exigir_feature("nutricion") }  # Fase 18d
  def create
    authorize RegistroCaloria, :create?
    datos = params.expect(registro_caloria: [ :kcal_consumidas, :detalle, :fecha,
                                              :proteinas_g, :carbohidratos_g, :grasas_g ])
    fecha = fecha_valida(datos[:fecha])
    return redirect_back_or_to objetivo_path, alert: "No puedes registrar un día futuro." if fecha > Date.current

    registro = RegistroCaloria.registrar(Current.user, kcal: datos[:kcal_consumidas], fecha: fecha,
                                         detalle: detalle_parseado(datos[:detalle]),
                                         **macros_recibidos(datos))

    # redirect_back (Fase 18k, reporte del cliente): registrar desde el
    # checklist de Mi plan teletransportaba a Nutrición. Volver a la MISMA
    # página deja que el morph de Turbo 8 (layout) actualice en sitio con el
    # scroll preservado — sensación SPA sin JS nuevo.
    if registro.persisted? && registro.errors.none?
      redirect_back_or_to objetivo_path, notice: "Consumo de hoy registrado."
    else
      redirect_back_or_to objetivo_path, alert: registro.errors.full_messages.to_sentence
    end
  end

  private

    # Editar el historial (Fase 5.11): fecha opcional, hoy por defecto.
    def fecha_valida(crudo)
      Date.iso8601(crudo.to_s)
    rescue ArgumentError
      Date.current
    end

    # Macros del checklist del plan (Fase 14.4): hidden fields opcionales.
    # Vacío = "sin dato" (nil), no cero — solo viajan las claves presentes,
    # para que un envío sin macros no borre los ya guardados del día.
    def macros_recibidos(datos)
      %i[proteinas_g carbohidratos_g grasas_g]
        .index_with { |campo| datos[campo].presence&.to_i }
        .compact
    end

    # El detalle llega como JSON serializado en un campo oculto (lo arma el
    # Stimulus del plan). Si viene roto, se ignora sin romper el registro.
    def detalle_parseado(crudo)
      return if crudo.blank?

      datos = JSON.parse(crudo)
      datos.is_a?(Hash) ? datos : nil
    rescue JSON::ParserError
      nil
    end
end
