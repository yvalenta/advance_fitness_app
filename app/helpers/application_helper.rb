module ApplicationHelper
  # Moneda COP sin decimales (SDD §12)
  def cop(monto)
    number_to_currency(monto, unit: "$", precision: 0, delimiter: ".", format: "%u%n")
  end

  def badge_estado(estado)
    clase = {
      "activa" => "badge-success",
      "vencida" => "badge-error",
      "suspendida" => "badge-warning",
      "checkin" => "badge-ghost",
      "reingreso" => "badge-info"
    }.fetch(estado, "badge-ghost")
    tag.span(estado, class: "badge badge-sm whitespace-nowrap #{clase}")
  end

  # Iniciales para el avatar (nombre o, en su defecto, correo)
  def iniciales(user)
    fuente = user.nombre.presence || user.email_address
    fuente.split(/[\s@._-]+/).reject(&:empty?).first(2).map { |palabra| palabra[0] }.join.upcase
  end

  def nombre_visible(user)
    user.nombre.presence || user.email_address
  end

  # Resumen corto de membresía para el popup de resumen del miembro (Fase 5.13)
  def resumen_membresia(user)
    membresia = user.membresia
    return "Sin membresía" unless membresia

    "#{membresia.estado.capitalize} · vence #{l membresia.fecha_vencimiento}"
  end

  # Traduce PlanPersonalizado#generado_por para vistas de staff (Fase 5.14):
  # evita repetir "ia"/"reglas" crudo y la palabra "IA" en el copy de cara al negocio.
  ORIGENES_PLAN = {
    "ia" => "análisis automático",
    "reglas" => "plan de membresía",
    "entrenador" => "entrenador"
  }.freeze

  def origen_plan(plan)
    ORIGENES_PLAN.fetch(plan.generado_por, plan.generado_por)
  end

  # Link del navbar con estado activo
  def nav_link(texto, ruta)
    activo = current_page?(ruta)
    clases = activo ? "bg-volt/15 text-volt" : "text-white/70 hover:bg-white/10 hover:text-white"
    link_to texto, ruta, class: "rounded-lg px-3 py-1.5 text-sm font-medium transition-colors #{clases}"
  end
end
