# Datos de demostración sobre los usuarios REALES ya existentes (Fase 5.11,
# ampliado Fase 12.1 con 2 meses de historial): completa perfiles, fija
# objetivos, y siembra pesos (mediciones), check-ins, calorías y —para
# usuarios premium con plan aprobado— series de entrenamiento reales, para
# poder probar el mínimo de datos del Analista de Performance
# (User::MINIMO_SEMANAS_PARA_ANALISIS). Idempotente: no duplica lo que ya
# exista y respeta los objetivos ya fijados. Excluye usuarios fixture
# (@example.com).
namespace :demo do
  SEMANAS_DEMO = 8 # ≈ 2 meses

  desc "Siembra objetivos, check-ins, pesos, calorías y entrenamientos (2 meses) para los usuarios existentes"
  task sembrar: :environment do
    admin = User.where(rol: "admin").order(:id).first
    abort "No hay usuario admin en la base." unless admin

    usuarios = User.where(rol: "miembro")
                   .where.not("email_address LIKE ?", "%@example.com").order(:id)

    usuarios.find_each do |miembro|
      azar = Random.new(miembro.id) # determinista por usuario → re-ejecutar no "baraja"

      completar_perfil(miembro, azar)
      objetivo = asegurar_objetivo(miembro, azar)
      sembrar_pesos(miembro, objetivo, admin, azar)
      sembrar_checkins(miembro, azar)
      sembrar_calorias(miembro, objetivo, azar)
      series_creadas = sembrar_entrenamientos(miembro, azar)

      puts "✓ #{miembro.nombre.presence || miembro.email_address} — objetivo: #{objetivo&.tipo || "—"} · " \
           "mediciones: #{miembro.mediciones.count} · check-ins: #{miembro.accesos.count} · " \
           "calorías: #{miembro.registros_calorias.count} · series: #{series_creadas}"
    end
  end

  # Perfil mínimo para calcular TDEE (solo campos faltantes; no pisa datos reales)
  def completar_perfil(miembro, azar)
    miembro.update!(
      fecha_nacimiento: miembro.fecha_nacimiento || (Date.current - (24 + azar.rand(18)).years - azar.rand(300).days),
      sexo: miembro.sexo || (miembro.nombre.to_s.split.first.to_s =~ /a\z/i ? "F" : "M"),
      talla_cm: miembro.talla_cm || (155 + azar.rand(30)),
      nivel_actividad: miembro.nivel_actividad || [ 1.4, 1.6, 1.8 ].sample(random: azar)
    )
  end

  def asegurar_objetivo(miembro, azar)
    return miembro.objetivo_activo if miembro.objetivo_activo

    ObjetivoNutricional.fijar_para(
      miembro,
      tipo: %w[deficit superavit mantenimiento].sample(random: azar),
      peso_kg: peso_base(miembro, azar)
    )
    miembro.objetivo_activo
  end

  # Serie de peso semanal (2 meses) que tiende hacia la meta del objetivo
  def sembrar_pesos(miembro, objetivo, admin, azar)
    base = objetivo&.peso_kg.to_f.positive? ? objetivo.peso_kg.to_f : peso_base(miembro, azar)
    direccion = { "deficit" => -1, "superavit" => 1 }.fetch(objetivo&.tipo, 0)

    (SEMANAS_DEMO - 1).downto(0) do |semanas|
      fecha = Date.current - semanas.weeks
      medicion = miembro.mediciones.find_or_initialize_by(fecha: fecha)
      next if medicion.persisted?

      peso = base + (direccion * 0.4 * (SEMANAS_DEMO - 1 - semanas)) + ((azar.rand - 0.5) * 0.6)
      medicion.update!(peso_kg: peso.round(1), talla_cm: miembro.talla_cm,
                       tomada_por: semanas == SEMANAS_DEMO - 1 ? admin : miembro)
    end
  end

  # 2–4 visitas por semana en las últimas 2 meses, en horario del gimnasio
  def sembrar_checkins(miembro, azar)
    membresia = miembro.membresia

    (0...SEMANAS_DEMO).each do |atras|
      semana = Date.current.beginning_of_week - atras.weeks
      (0..5).to_a.sample(2 + azar.rand(3), random: azar).each do |offset|
        dia = semana + offset
        next if dia > Date.current
        next if miembro.accesos.exists?(fecha_hora: dia.all_day)

        hora = Time.zone.local(dia.year, dia.month, dia.day, 6 + azar.rand(14), 15 * azar.rand(4))
        Acceso.registrar_para(miembro, membresia, ahora: hora)
      end
    end
  end

  # Calorías diarias de los últimos 2 meses, oscilando cerca del objetivo
  # (o de un TDEE estimado si no hay objetivo fijado).
  def sembrar_calorias(miembro, objetivo, azar)
    meta = objetivo&.objetivo_kcal.to_i.positive? ? objetivo.objetivo_kcal : 2000

    (SEMANAS_DEMO * 7 - 1).downto(0) do |dias|
      fecha = Date.current - dias.days
      next if miembro.registros_calorias.exists?(fecha: fecha)
      next if azar.rand < 0.15 # algunos días sin registrar, como en la vida real

      kcal = (meta + ((azar.rand - 0.5) * 300)).round
      miembro.registros_calorias.create!(fecha: fecha, kcal_consumidas: kcal)
    end
  end

  # Series reales de entrenamiento (feature premium, SDD §18) para los
  # últimos 2 meses: solo si el miembro tiene suscripción activa al plan
  # Personalizado — sin eso el Analista de Performance no aplica igual.
  # 3–4 sesiones por semana sobre un set fijo de ejercicios del catálogo,
  # con progresión leve de peso a lo largo de las semanas.
  def sembrar_entrenamientos(miembro, azar)
    return 0 unless miembro.premium?

    ejercicios = Ejercicio.fuerza.ordenados.limit(5).to_a
    return 0 if ejercicios.empty?

    creadas = 0
    (0...SEMANAS_DEMO).each do |atras|
      semana = Date.current.beginning_of_week - atras.weeks
      progreso_semana = SEMANAS_DEMO - 1 - atras

      (0..4).to_a.sample(3 + azar.rand(2), random: azar).each do |offset|
        fecha = semana + offset
        next if fecha > Date.current

        registro = miembro.registros_entrenamiento.find_or_create_by!(fecha: fecha)
        ejercicios.sample(3, random: azar).each do |ejercicio|
          next if registro.detalles.exists?(ejercicio: ejercicio)

          peso_base_ej = 20 + (azar.rand * 40)
          3.times do |serie|
            registro.detalles.create!(
              ejercicio: ejercicio, serie: serie + 1,
              repeticiones: 8 + azar.rand(5),
              peso_kg: (peso_base_ej + progreso_semana * 0.8 + (azar.rand - 0.5) * 2).round(1),
              rpe: 6 + azar.rand(4)
            )
            creadas += 1
          end
        end
      end
    end
    creadas
  end

  # Peso inicial coherente con la talla (IMC 22–28)
  def peso_base(miembro, azar)
    imc = 22 + (azar.rand * 6)
    (imc * ((miembro.talla_cm.to_f / 100)**2)).round(1)
  end
end
