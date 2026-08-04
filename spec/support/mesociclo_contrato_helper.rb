# Fase 14.9 — stub del CONTRATO del mesociclo (la capa de modelo real es de
# 14.7 y se integra aparte). La UI del eje de semanas se prueba contra este
# API exacto, sin acoplarse al esquema jsonb interno de rutina["semanas"]:
# así los specs siguen en verde cuando el placeholder (MesocicloPlaceholder)
# sea reemplazado por la implementación real.
module MesocicloContratoHelper
  # Convierte cualquier plan en un mesociclo de `total` semanas cuyos días son
  # los de su rutina base. `actual` queda anclada a la semana calendario en
  # curso (lunes), igual que el contrato: fecha_de(actual, 0) == este lunes.
  def stubear_mesociclo(total: 4, actual: 2, descarga: [], materializadas: [])
    allow_any_instance_of(PlanPersonalizado).to receive(:semanas) do |plan|
      base = Array(plan.rutina["dias"])
      (1..total).map do |n|
        { "numero" => n, "etiqueta" => "Semana #{n}", "descarga" => descarga.include?(n),
          "ajuste" => nil, "dias" => base }
      end
    end
    allow_any_instance_of(PlanPersonalizado).to receive(:semana) do |plan, numero|
      plan.semanas.find { |s| s["numero"] == numero.to_i }
    end
    allow_any_instance_of(PlanPersonalizado).to receive(:dias) do |plan, semana: nil|
      Array(plan.rutina["dias"])
    end
    allow_any_instance_of(PlanPersonalizado).to receive(:semana_actual).and_return(actual)
    allow_any_instance_of(PlanPersonalizado).to receive(:mesociclo_completado?).and_return(false)
    allow_any_instance_of(PlanPersonalizado).to receive(:semana_materializada?) do |_plan, numero|
      materializadas.include?(numero.to_i)
    end
    allow(Rutina::Calendario).to receive(:fecha_de) do |_plan, semana:, dia_indice:|
      Date.current.beginning_of_week + (semana - actual).weeks + dia_indice
    end
  end
end

RSpec.configure do |config|
  config.include MesocicloContratoHelper, type: :request
end
