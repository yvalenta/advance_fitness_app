# Tablas que llevan `tenant_id` propio en vez de derivarlo por join a `users`
# (SDD §16.7, Etapa 1.3): `membresias`, `pagos` y `suscripciones`.
#
# Vive en un solo lugar a propósito: es un control de seguridad, y tres copias
# de la misma lógica son tres sitios donde arreglar la mitad de un bug. Lo que
# garantiza es que **no se pueda persistir una fila incoherente**, aunque el
# controller que la crea se olvide del tenant:
#
#   · lo hereda del dueño si viene en blanco (el caso normal — ningún
#     call-site existente tuvo que cambiar), y
#   · rechaza la fila si el `tenant_id` no coincide con el del dueño (el caso
#     malicioso o el bug: un `tenant_id` inyectado por mass-assignment).
#
# Uso: `hereda_tenant_de :user` (o `:membresia`, que ya trae su propio
# `tenant_id` desnormalizado — un salto menos que ir hasta `membresia.user`).
module TenantDesnormalizado
  extend ActiveSupport::Concern

  class_methods do
    def hereda_tenant_de(asociacion)
      # optional: true — la columna es nullable a nivel de base para que un
      # rollback de la migración no falle (§16.7). La exigencia real es la
      # coherencia de abajo: si el dueño tiene tenant, la fila también.
      belongs_to :tenant, optional: true

      before_validation do
        self.tenant_id ||= public_send(asociacion)&.tenant_id
      end

      validate do
        dueno = public_send(asociacion)
        next if dueno.nil?

        if tenant_id != dueno.tenant_id
          errors.add(:tenant_id, "debe coincidir con el de #{asociacion}")
        end
      end
    end
  end
end
