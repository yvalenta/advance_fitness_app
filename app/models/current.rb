class Current < ActiveSupport::CurrentAttributes
  # `tenant` viene del subdominio (SDD §16.6, `TenantScoping`); es nil en el
  # portal comercial (`comercial`/`app`.ynt.codes) y para requests fuera del
  # ciclo web (jobs, mailers, especs de modelo).
  #
  # `puesto` es el puesto VIGENTE del par (Current.user, Current.tenant) —
  # la pertenencia N:M de la tarea 2026-08-31. Lo carga
  # `verificar_pertenencia_al_tenant` con UNA query por request (el pooler de
  # producción tiene 15 conexiones: nadie más debe repetir esa query — leé
  # este atributo). Es nil para los roles globales (superadmin y
  # comercializador no tienen puestos), en el portal comercial y fuera del
  # ciclo web.
  attribute :session, :tenant, :landing_slug, :puesto
  delegate :user, to: :session, allow_nil: true
end
