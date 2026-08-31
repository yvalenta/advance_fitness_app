# frozen_string_literal: true

class MembresiaPolicy < ApplicationPolicy
  def index?
    user.staff? || user.mostrador?
  end

  def show?
    propia? || ((user.staff? || user.mostrador?) && del_gimnasio_del_staff?)
  end

  def create?
    (user.staff? || user.mostrador?) && del_gimnasio_del_staff?
  end

  def update?
    (user.staff? || user.mostrador?) && del_gimnasio_del_staff?
  end

  # Renovar = pago + extensión del vencimiento. Va con quien cobra: admin y
  # recepción (antes solo admin, porque `recepcion` no existía y el único que
  # registraba pagos era él).
  def renovar?
    user.mostrador? && del_gimnasio_del_staff?
  end

  def destroy?
    false
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.staff? || user.mostrador?
        del_tenant_directo(scope)
      else
        scope.where(user_id: user.id)
      end
    end
  end

  private
    def propia?
      record.user_id == user.id
    end

    # Defensa en profundidad (tarea 2026-08-31): además del rol, la fila debe
    # anclar en el gimnasio del viewer aunque el controller la cargue con un
    # find crudo. Persistida, manda su `tenant_id` desnormalizado (SDD §16.7);
    # nueva (#create con user_id del form), manda el tenant ESTACIONADO del
    # dueño — el mismo ancla que le heredará TenantDesnormalizado: el dinero
    # se opera donde la cuenta está estacionada. Sin dueño todavía (#new, o
    # un user_id inexistente) se deja pasar: la validación de presencia lo
    # frena al guardar, y acá no hay tenant que comparar.
    def del_gimnasio_del_staff?
      return true unless record.is_a?(Membresia)
      if record.persisted?
        record.tenant_id == user.tenant_id
      else
        record.user.nil? || record.user.tenant_id == user.tenant_id
      end
    end
end
