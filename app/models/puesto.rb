# Un puesto = la pertenencia de una CUENTA a UN gimnasio, con el rol que
# tiene AHÍ (tarea 2026-08-31). Es la pieza N:M del multi-tenant: la verdad
# de "a qué tenants pertenece este user y como qué" vive acá;
# `users.tenant_id`/`users.rol` quedan como cache del puesto donde la cuenta
# está parada ahora (contrato redefinido en User).
#
# NO se llama Membresia a propósito: `Membresia` ya es la del gimnasio — la
# que se paga y se vence. Esto es un puesto: pertenencia con rol.
class Puesto < ApplicationRecord
  # superadmin y comercializador operan el portal comercial global (SDD
  # §16.6): no tienen puesto en ningún gimnasio, jamás.
  ROLES = (User::ROLES - User::ROLES_GLOBALES).freeze

  belongs_to :user
  belongs_to :tenant

  validates :rol, inclusion: { in: ROLES }
  # Un solo puesto por (cuenta, gimnasio); el único de la base respalda la
  # validación ante una carrera.
  validates :user_id, uniqueness: { scope: :tenant_id, message: "ya tiene un puesto en esta organización" }
end
