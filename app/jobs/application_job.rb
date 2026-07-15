class ApplicationJob < ActiveJob::Base
  # El pooler de Supabase (modo sesión, límite de 15 clientes) se satura en
  # la ventana de deploy en que conviven dos contenedores (drain_timeout 130s):
  # los jobs morían de una con ConnectionNotEstablished (julio 2026, 19 fallos
  # acumulados, todos alineados con deploys). Reintentar con espera creciente
  # los saca de esa ventana en vez de perderlos.
  retry_on ActiveRecord::ConnectionNotEstablished, wait: :polynomially_longer, attempts: 5
end
