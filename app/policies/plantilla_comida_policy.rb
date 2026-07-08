# Las plantillas son herramienta de staff: el miembro nunca las toca.
class PlantillaComidaPolicy < ApplicationPolicy
  def create? = user.staff?
  def destroy? = user.staff?
end
