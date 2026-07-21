# CRUD de tenants (SDD §16.6): opera en el portal comercial (Current.tenant
# nil, subdominio `comercial`/`app`). El alta también crea al admin inicial
# del tenant y le manda el correo de "reset de contraseña" ya existente para
# que fije su clave y entre por su propio subdominio.
class Superadmin::TenantsController < ApplicationController
  before_action :cargar_tenant, only: %i[ show edit update destroy ]

  def index
    authorize Tenant
    @tenants = Tenant.order(:nombre).includes(:users)
  end

  def show
    authorize @tenant
  end

  def new
    authorize Tenant
    @tenant = Tenant.new(tipo_entidad: "gimnasio",
                         features_habilitadas: { "membresias" => true },
                         paleta_colores: {})
  end

  def create
    @tenant = Tenant.new(tenant_params_normalizados)
    authorize @tenant

    if @tenant.save
      admin = crear_admin_inicial(@tenant)
      redirect_to superadmin_tenant_path(@tenant),
                  notice: admin ? "Tenant creado. Enviamos a #{admin.email_address} el enlace para fijar su contraseña." : "Tenant creado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @tenant
  end

  def update
    authorize @tenant
    if @tenant.update(tenant_params_normalizados)
      redirect_to superadmin_tenant_path(@tenant), notice: "Tenant actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @tenant
    redirect_to superadmin_tenants_path, alert: "La eliminación de tenants está deshabilitada. Marca el tenant como inactivo."
  end

  private
    def cargar_tenant
      @tenant = Tenant.find(params[:id])
    end

    def tenant_params
      params.expect(tenant: [ :nombre, :slug, :tipo_entidad, :email_contacto, :activo,
                              :precio_mensualidad, :precio_personalizado, :duracion_dias, :logo,
                              :admin_nombre, :admin_email,
                              paleta_colores: %i[ volt primary accent ],
                              features_habilitadas: %i[ membresias ] ])
    end

    # Membresías se apagan por defecto si el tenant no es gimnasio y el form
    # no marcó el checkbox (form checkbox no manda la clave si viene sin
    # marcar y sin hidden 0). Los precios y colores vacíos se guardan como
    # nil / {} para caer al fallback global de Negocio.
    def tenant_params_normalizados
      atributos = tenant_params.to_h.except(:admin_nombre, :admin_email)

      atributos[:paleta_colores] = atributos.fetch(:paleta_colores, {}).compact_blank
      atributos[:features_habilitadas] = { "membresias" => atributos.dig(:features_habilitadas, :membresias) == "1" }

      atributos.slice(:precio_mensualidad, :precio_personalizado, :duracion_dias).each_key do |campo|
        atributos[campo] = atributos[campo].presence
      end

      atributos
    end

    def crear_admin_inicial(tenant)
      email = params.dig(:tenant, :admin_email).to_s.strip.downcase
      nombre = params.dig(:tenant, :admin_nombre).to_s.strip
      return if email.blank?

      admin = User.find_or_initialize_by(email_address: email)
      admin.assign_attributes(nombre: nombre.presence || admin.nombre.presence || email,
                              tenant: tenant, rol: "admin",
                              password: SecureRandom.base58(32))
      admin.save!
      PasswordsMailer.reset(admin).deliver_later
      admin
    end
end
