class Admin::UsersController < ApplicationController
  def index
    authorize User
    @q = params[:q].to_s.strip
    # La lista enumera por PUESTOS del gimnasio (UserPolicy::Scope hace el
    # join) y el rol que se muestra es EL DEL PUESTO acá — no `users.rol`,
    # que es la cache del gimnasio donde la cuenta está estacionada: para un
    # miembro estacionado en otro tenant mostraría el rol de allá.
    @users = policy_scope(User).select("users.*, puestos.rol AS rol_del_puesto")
                               .includes(:membresia).order(:nombre)
    @users = @users.where("nombre ILIKE :q OR email_address ILIKE :q", q: "%#{User.sanitize_sql_like(@q)}%") if @q.present?
    @users = @users.page(params[:page]).per(25)
  end

  def show
    # policy_scope + find (tarea 2026-08-31): la doble capa. UserPolicy#show?
    # ya exige puesto en el tenant del staff; el scope hace que un ID ajeno
    # ni siquiera cargue — 404 indistinguible en vez de un redirect que
    # confirma que el ID existe.
    @user = policy_scope(User).find(params[:id])
    authorize @user
    cargar_ficha
  end

  ROLES_ASIGNABLES = %w[miembro entrenador recepcion admin].freeze

  def new
    authorize User, :create?
    @user = User.new(rol: "miembro")
  end

  def create
    authorize User, :create?
    rol = params.dig(:user, :rol).to_s
    rol = "miembro" unless ROLES_ASIGNABLES.include?(rol)

    # El puesto del par (user, tenant) nace solo, con este mismo rol: lo
    # materializa el after_save de User (invariante cache ↔ puestos).
    @user = User.new(
      nombre:        params.dig(:user, :nombre),
      email_address: params.dig(:user, :email_address),
      tenant:        Current.user.tenant,
      rol:           rol
    )
    # Contraseña temporal aleatoria; el usuario la fija vía el link de reset
    @user.password = SecureRandom.hex(16)

    if @user.save
      PasswordsMailer.reset(@user).deliver_later
      redirect_to admin_users_path,
                  notice: "#{@user.nombre.presence || @user.email_address} agregado. Se envió el enlace para fijar su contraseña."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Dashboard del miembro (Fase 6.13): datos básicos editables por staff.
  # El rol y el VIP NUNCA se mass-asignan (regla del proyecto) — se aplican
  # aparte y solo si quien edita es admin (un entrenador no puede ascender a
  # nadie ni otorgar acceso VIP sin vencimiento, Fase 12.2).
  #
  # El cambio de rol aterriza en el PUESTO de ESTE gimnasio (la verdad,
  # tarea 2026-08-31); la cache `users.rol` solo se toca si la cuenta está
  # estacionada acá — estacionada en otro tenant, la cache es el rol de ese
  # otro y pisarla lo cambiaría de rol ALLÁ. También se filtra contra
  # ROLES_ASIGNABLES como en `create` (antes cualquier string del param
  # llegaba a `users.rol`, "superadmin" incluido).
  def update
    # Mismo patrón que #show: un ID de otro gimnasio no existe acá (404).
    @user = policy_scope(User).find(params[:id])
    authorize @user
    rol_nuevo = params[:user][:rol].to_s
    rol_nuevo = nil unless Current.user.admin? && ROLES_ASIGNABLES.include?(rol_nuevo)
    @user.vip = ActiveModel::Type::Boolean.new.cast(params[:user][:vip]) if Current.user.admin? && params[:user].key?(:vip)

    exito = false
    ActiveRecord::Base.transaction do
      if rol_nuevo
        @user.puestos.find_by(tenant_id: Current.tenant.id)&.update!(rol: rol_nuevo)
        @user.rol = rol_nuevo if @user.tenant_id == Current.tenant.id
      end
      exito = @user.update(user_params)
      raise ActiveRecord::Rollback unless exito
    end

    if exito
      redirect_to admin_user_path(@user), notice: "Perfil actualizado."
    else
      cargar_ficha
      render :show, status: :unprocessable_entity
    end
  end

  private
    # La ficha del miembro tiene DOS mitades (Fase 18k). La de mostrador
    # —perfil, membresía y últimos accesos— la ve cualquiera que llegue hasta
    # acá; la de entrenamiento —plan, antropometría, progreso y Analista— es
    # solo para `staff?`. Recepción abre la ficha para cobrar y dar acceso, y
    # no debe leer de paso el plan ni las medidas: por eso la mitad de
    # entrenamiento ni siquiera se CONSULTA (esconderla en la vista dejaría
    # los datos cargados y una query de más).
    def cargar_ficha
      # El rol que la ficha muestra y preselecciona es el del PUESTO en ESTE
      # gimnasio; la cache `users.rol` puede ser el rol de otro tenant si la
      # cuenta está estacionada allá. El fallback cubre el caso sin puesto
      # (solo alcanzable viendo la propia ficha, donde cache y puesto van
      # de la mano).
      @rol_en_este_gimnasio = @user.puestos.find_by(tenant_id: Current.tenant.id)&.rol || @user.rol
      @accesos = @user.accesos.recientes.limit(10)
      return unless Current.user.staff?

      @plan = @user.plan_actual
      @progreso = ProgresoUsuario.para(@user)
      @registro_reciente = @user.registros_entrenamiento.order(fecha: :desc).first
    end

    def user_params
      params.expect(user: %i[nombre email_address fecha_nacimiento sexo nivel_actividad somatotipo])
    end
end
