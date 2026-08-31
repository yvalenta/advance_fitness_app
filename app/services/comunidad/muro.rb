# Muro de la comunidad (Fase 18e): celebraciones DERIVADAS en lectura de los
# récords personales y logros recientes de miembros del tenant con
# consentimiento vigente `logros_comunidad`. Sin tabla nueva y sin jobs — los
# datos ya existen (motor de juego, Fase 14.12/14.13), el muro solo los
# cuenta. Nombre visible: la misma promesa del ranking — apodo o nombre de
# pila, jamás el correo.
module Comunidad
  class Muro
    Celebracion = Struct.new(:fecha, :emoji, :texto, :detalle, keyword_init: true)

    LIMITE = 15

    def self.celebraciones(tenant, limite: LIMITE)
      new(tenant, limite).celebraciones
    end

    def initialize(tenant, limite)
      @tenant = tenant
      @limite = limite
    end

    def celebraciones
      return [] if @tenant.nil? || participantes.empty?

      (de_records + de_logros).sort_by(&:fecha).reverse.first(@limite)
    end

    private
      # Solo miembros (el staff no compite) y solo con opt-in vigente.
      # Enumerados por PUESTO de miembro en este tenant (tarea 2026-08-31),
      # no por la cache users.tenant_id/rol: quien tiene puesto de miembro
      # acá celebra acá, esté estacionado donde esté.
      def participantes
        @participantes ||= Consentimiento.usuarios_vigentes(
          "logros_comunidad",
          Puesto.where(tenant_id: @tenant.id, rol: "miembro").pluck(:user_id))
      end

      # "Nueva marca" y no "rompió su récord": el vigente puede ser el
      # baseline del primer registro (Fase 14.13) y el texto vale para ambos.
      def de_records
        RecordPersonal.vigentes.where(user_id: participantes)
                      .includes(:ejercicio, user: :perfil_juego)
                      .order(fecha: :desc, id: :desc).limit(@limite).map do |record|
          Celebracion.new(fecha: record.fecha, emoji: "💪",
                          texto: "#{nombre_de(record.user)} logró nueva marca en #{record.ejercicio.nombre}",
                          detalle: record.marca)
        end
      end

      def de_logros
        LogroObtenido.where(user_id: participantes)
                     .includes(:logro, user: :perfil_juego)
                     .order(obtenido_en: :desc).limit(@limite).map do |obtenido|
          Celebracion.new(fecha: obtenido.obtenido_en.to_date,
                          emoji: obtenido.logro.icono.presence || "🏅",
                          texto: "#{nombre_de(obtenido.user)} desbloqueó “#{obtenido.logro.nombre}”",
                          detalle: obtenido.logro.puntos.positive? ? "+#{obtenido.logro.puntos} pts" : nil)
        end
      end

      def nombre_de(user)
        user.perfil_juego&.apodo.presence || user.nombre.to_s.split.first.presence || "Miembro"
      end
  end
end
