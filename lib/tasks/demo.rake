# Datos de demostración sobre los usuarios REALES ya existentes (Fase 5.11):
# completa perfiles, fija objetivos, y siembra pesos (mediciones) y check-ins
# coherentes con cada meta. Idempotente: no duplica lo que ya exista y respeta
# los objetivos ya fijados. Excluye usuarios fixture (@example.com).
namespace :demo do
  desc "Siembra objetivos, check-ins y pesos para los usuarios existentes"
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

      puts "✓ #{miembro.nombre.presence || miembro.email_address} — objetivo: #{objetivo&.tipo || "—"} · " \
           "mediciones: #{miembro.mediciones.count} · check-ins: #{miembro.accesos.count}"
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

  # Serie de peso semanal (7 puntos) que tiende hacia la meta del objetivo
  def sembrar_pesos(miembro, objetivo, admin, azar)
    base = objetivo&.peso_kg.to_f.positive? ? objetivo.peso_kg.to_f : peso_base(miembro, azar)
    direccion = { "deficit" => -1, "superavit" => 1 }.fetch(objetivo&.tipo, 0)

    6.downto(0) do |semanas|
      fecha = Date.current - semanas.weeks
      medicion = miembro.mediciones.find_or_initialize_by(fecha: fecha)
      next if medicion.persisted?

      peso = base + (direccion * 0.4 * (6 - semanas)) + ((azar.rand - 0.5) * 0.6)
      medicion.update!(peso_kg: peso.round(1), talla_cm: miembro.talla_cm,
                       tomada_por: semanas == 6 ? admin : miembro)
    end
  end

  # 2–4 visitas por semana en las últimas 6 semanas, en horario del gimnasio
  def sembrar_checkins(miembro, azar)
    membresia = miembro.membresia

    (0..5).each do |atras|
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

  # Peso inicial coherente con la talla (IMC 22–28)
  def peso_base(miembro, azar)
    imc = 22 + (azar.rand * 6)
    (imc * ((miembro.talla_cm.to_f / 100)**2)).round(1)
  end
end
