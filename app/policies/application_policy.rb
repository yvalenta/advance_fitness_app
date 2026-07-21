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
    def del_tenant(relation, por: :user)
      return relation.none if user.tenant_id.blank?
      relation.where(por => user.tenant.users)
    end
  end
end
