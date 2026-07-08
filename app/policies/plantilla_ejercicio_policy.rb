# Las plantillas de ejercicio son herramienta de staff (como las de comida).
class PlantillaEjercicioPolicy < ApplicationPolicy
  def create? = user.staff?
  def destroy? = user.staff?
end
