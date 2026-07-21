class Current < ActiveSupport::CurrentAttributes
  # `tenant` viene del subdominio (SDD §16.6, `TenantScoping`); es nil en el
  # portal comercial (`comercial`/`app`.ynt.codes) y para requests fuera del
  # ciclo web (jobs, mailers, especs de modelo).
  attribute :session, :tenant, :landing_slug
  delegate :user, to: :session, allow_nil: true
end
