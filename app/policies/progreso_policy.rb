# Policy "headless": /progreso solo muestra datos del propio usuario
class ProgresoPolicy < Struct.new(:user, :progreso)
  def show?
    user.present?
  end
end
