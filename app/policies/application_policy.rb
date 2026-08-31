# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope

    # Row-level multi-tenancy (SDD §16.6): reemplaza el `scope.all` que las
    # ramas de staff usaban antes por un filtro que solo devuelve registros
    # cuyo dueño pertenece al mismo tenant que `user`. `por:` es el nombre de
    # la asociación al `User` dueño (o la cadena de `joins`) que la policy
    # concreta le pasa; el default cubre el caso más común (`belongs_to :user`).
    #
    # "Pertenece" sale del PUESTO (tarea 2026-08-31), no de la cache
    # `users.tenant_id`: los datos de un miembro con puesto acá pero
    # estacionado en otro gimnasio siguen visibles para el staff de acá — con
    # la cache desaparecían de todas las listas (el miembro invisible). El
    # tenant del VIEWER sí sale de su cache: `verificar_pertenencia_al_tenant`
    # garantiza que coincide con el subdominio en cada request.
    def del_tenant(relation, por: :user)
      return relation.none if user.tenant_id.blank?
      relation.where(por => User.joins(:puestos).where(puestos: { tenant_id: user.tenant_id }))
    end

    # Variante para las tablas que llevan `tenant_id` propio (SDD §16.7:
    # `membresias`, `pagos`, `suscripciones`): filtra por la columna, sin join
    # ni subconsulta. Mismo contrato fail-closed que `del_tenant` — sin tenant
    # no se ve nada, en vez de verse todo.
    def del_tenant_directo(relation)
      return relation.none if user.tenant_id.blank?
      relation.where(tenant_id: user.tenant_id)
    end
  end
end
