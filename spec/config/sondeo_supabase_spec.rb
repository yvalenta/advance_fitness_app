require "rails_helper"

# Solid Queue y Solid Cable sondean la base de Supabase por el pooler, y cada
# vuelta es egress contra la cuota Free de 5 GB de la organización. Con los
# defaults del generador (0.1 s) el worker solo se comía casi toda la cuota
# (2026-09-30, ver los comentarios de config/queue.yml y config/cable.yml).
# Esta guarda pone rojo un regreso a esos defaults — por ejemplo, al
# regenerar la config con un `solid_queue:install`.
RSpec.describe "Sondeo de Solid Queue y Solid Cable contra Supabase" do
  %w[workers dispatchers].each do |tipo|
    it "los #{tipo} de Solid Queue en producción sondean cada 2 s o más" do
      produccion = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/queue.yml")).fetch("production")
      intervalos = produccion.fetch(tipo).map { |proceso| proceso.fetch("polling_interval") }

      expect(intervalos).to be_present
      expect(intervalos).to all(be >= 2)
    end
  end

  it "Solid Cable en producción sondea cada 1 s o más, leído como lo lee la gema" do
    allow(SolidCable).to receive(:cable_config).and_return(Rails.application.config_for("cable", env: "production"))

    expect(SolidCable.polling_interval).to be >= 1.second
  end
end
