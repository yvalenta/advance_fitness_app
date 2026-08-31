# Log append-only del embudo de cambio de organización (tarea 2026-08-31):
# cada salto entre subdominios deja una FILA — quién, de dónde, a dónde, IP
# y user-agent — mismo espíritu auditable que `Consentimiento` y `pagos`: se
# deja rastro, jamás se edita ni se borra físico. Sin updated_at.
#
# `token_digest` + su índice único en la base = el pase firmado es de UN
# SOLO USO: canjearlo dos veces revienta contra el único, sin depender de la
# aplicación. Es nullable para las filas de auditoría sin pase (p. ej.
# superadmin entrando a un tenant).
class CambioOrganizacion < ApplicationRecord
  belongs_to :user
  # nil cuando el salto arranca fuera de un tenant (portal comercial).
  belongs_to :de_tenant, class_name: "Tenant", optional: true
  belongs_to :a_tenant, class_name: "Tenant"

  # Append-only a nivel de modelo, no solo de policy: una fila persistida es
  # de solo lectura — update/destroy levantan ActiveRecord::ReadOnlyRecord.
  def readonly? = persisted?
end
