require "rails_helper"

# config/recurring.yml solo tiene sección production: un schedule que fugit no
# entiende o una clase renombrada no se veía hasta que el scheduler arrancaba
# en producción. Acá corre la misma validación que `bin/jobs check`
# (solid_queue 1.5+) sobre esa sección, y se fija la hora de la escalera.
RSpec.describe "config/recurring.yml" do
  let(:produccion) do
    ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml"))
      .deep_symbolize_keys.fetch(:production)
  end

  # RecurringTask es un modelo AR y la base de test no carga el esquema de la
  # cola: se carga dentro de la transacción del ejemplo (en Postgres el DDL
  # es transaccional) y el rollback lo deshace.
  before do
    ActiveRecord::Migration.suppress_messages { load Rails.root.join("db/queue_schema.rb") }
    SolidQueue::RecurringTask.reset_column_information
  end

  # Configuration solo acepta la RUTA de un YAML en recurring_schedule_file (un
  # Hash revienta con TypeError en warn_about_missing_config_files), y sin la
  # clave de entorno toma el archivo entero como el mapa de tareas. Un archivo
  # vacío validaría en vacío (cero tareas, sin error): el segundo expect lo
  # cierra pidiendo que el scheduler cargó las tareas de producción.
  it "pasa la validación de Solid Queue (bin/jobs check)" do
    Tempfile.create([ "recurring", ".yml" ]) do |archivo|
      archivo.write(produccion.deep_stringify_keys.to_yaml)
      archivo.flush

      configuracion = SolidQueue::Configuration.new(recurring_schedule_file: archivo.path)
      scheduler = configuracion.configured_processes.find { |proceso| proceso.kind == :scheduler }

      # valid? antes del expect: el mensaje de be_valid se arma antes de que el
      # matcher valide y salía vacío; así el rojo dice qué tarea falla.
      configuracion.valid?

      expect(configuracion.errors.full_messages).to be_empty
      expect(scheduler.attributes[:recurring_tasks].map { |tarea| tarea.key.to_sym }).to match_array(produccion.keys)
    end
  end

  it "corre la escalera de las 4am en hora de Bogotá, no en la del contenedor" do
    escalera = { vencer_membresias: "04:00", vencer_suscripciones: "04:02",
                 activar_suscripciones_programadas: "04:05", recalcular_perfiles_juego: "04:10" }

    horas = escalera.keys.index_with do |clave|
      tarea = SolidQueue::RecurringTask.from_configuration(clave, **produccion.fetch(clave))
      tarea.next_time.in_time_zone("America/Bogota").strftime("%H:%M")
    end

    expect(horas).to eq(escalera)
  end
end
