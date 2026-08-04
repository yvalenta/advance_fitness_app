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

  # data-theme del body según la preferencia del usuario (Fase 16, Nota 21).
  # "sistema" devuelve nil: SIN atributo, el CSS resuelve solo (default claro
  # + prefersdark del tema advance). Invitados y "oscuro" fuerzan advance.
  def tema_data_theme
    case Current.user&.tema
    when "claro" then "advance-claro"
    when "sistema" then nil
    else "advance"
    end
  end

  # data-acento del body (Fase 17, Nota 22f): nil con "volt" (el default de
  # la marca/tenant) para no emitir atributo ni pelear especificidades.
  def acento_data
    acento = Current.user&.acento
    acento unless acento.blank? || acento == "volt"
  end

  # <meta theme-color> acompañando al tema activo (Fase 16): oscuro usa el
  # color del tenant (Negocio.theme_color), claro el hueso del fondo, y
  # sistema emite AMBAS metas con media query para que el navegador elija.
  def metas_theme_color
    case Current.user&.tema
    when "claro"
      tag.meta(name: "theme-color", content: Negocio::THEME_COLOR_CLARO)
    when "sistema"
      safe_join([
        tag.meta(name: "theme-color", media: "(prefers-color-scheme: dark)", content: Negocio.theme_color),
        tag.meta(name: "theme-color", media: "(prefers-color-scheme: light)", content: Negocio::THEME_COLOR_CLARO)
      ])
    else
      tag.meta(name: "theme-color", content: Negocio.theme_color)
    end
  end

  # Link del navbar con estado activo
  def nav_link(texto, ruta)
    activo = current_page?(ruta)
    clases = activo ? "bg-volt/15 text-volt" : "text-white/70 hover:bg-white/10 hover:text-white"
    link_to texto, ruta, class: "rounded-lg px-3 py-1.5 text-sm font-medium transition-colors #{clases}"
  end
end
