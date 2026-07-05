# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Admin inicial (idempotente). En producción cambia la contraseña de
# inmediato o crea el admin real y elimina este.
admin = User.find_or_create_by!(email_address: "admin@advancefitness.local") do |user|
  user.nombre = "Administrador"
  user.rol = "admin"
  user.password = ENV.fetch("SEED_ADMIN_PASSWORD", "cambiame-ya-123")
end
admin.update!(rol: "admin") unless admin.admin?

# Promueve a admin un correo existente (útil para tu usuario de Google):
#   ADMIN_EMAIL=tu@correo.com bin/rails db:seed
if ENV["ADMIN_EMAIL"].present?
  User.find_by(email_address: ENV["ADMIN_EMAIL"])&.update!(rol: "admin")
end
