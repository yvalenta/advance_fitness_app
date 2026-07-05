class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Login con Google: encuentra o crea el usuario por email verificado.
  # Los usuarios creados vía OAuth reciben un password aleatorio (pueden
  # fijar el suyo luego con el flujo de reset).
  def self.from_omniauth(auth)
    find_or_create_by!(email_address: auth.info.email) do |user|
      user.password = SecureRandom.base58(32)
    end
  end
end
