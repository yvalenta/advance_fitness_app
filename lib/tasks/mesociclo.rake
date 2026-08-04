# Migración del contrato `rutina` v1 → v2 con mesociclo (SDD Fase 14.7). Se
# corre A MANO tras el deploy de la fase, con dry-run por defecto (mismo
# ritual que multi_tenant:migrar). Idempotente: un plan ya v2 se salta.
#
# Uso:
#   dip rails mesociclo:migrar               # dry-run: solo reporta qué cambiaría
#   APLICAR=1 dip rails mesociclo:migrar     # escribe de verdad
#   APLICAR=1 dip rails mesociclo:revertir   # v2 → v1 (lossless si nada materializado)
#   ... revertir FORZAR=1                    # revierte TAMBIÉN planes con semanas
#                                            # materializadas (descarta sus ediciones)
#
# ⚠ Con DEV_DATABASE_URL activo la consola dev apunta a Supabase (producción):
# ambas tareas abortan salvo que además pases CONFIRMO=1.
#
# La migración envuelve la rutina existente SIN tocar sus días: version 2,
# mesociclo estándar de 4 semanas identidad (el entrenador ajusta la
# progresión después) iniciando el lunes de la semana en que se corre, y
# semanas heredando la base ("dias" => nil). Por eso revertir es lossless
# mientras ninguna semana se haya materializado.

def mesociclo_guardia_supabase!
  return unless Rails.env.development? && ENV["DEV_DATABASE_URL"].present?
  return if ENV["CONFIRMO"] == "1"

  abort "⚠ DEV_DATABASE_URL activo: esta consola apunta a Supabase (producción). " \
        "Corre con CONFIRMO=1 solo si de verdad quieres operar sobre esa base."
end

namespace :mesociclo do
  SEMANAS_POR_DEFECTO = 4

  desc "Envuelve las rutinas v1 en el contrato v2 con mesociclo (dry-run sin APLICAR=1)"
  task migrar: :environment do
    mesociclo_guardia_supabase!
    aplicar = ENV["APLICAR"] == "1"
    puts aplicar ? "═══ Migración rutina v1 → v2 (ESCRIBIENDO) ═══" :
                   "═══ Migración rutina v1 → v2 (dry-run; APLICAR=1 para escribir) ═══"

    migrados = ya_v2 = sin_rutina = 0
    inicio = Date.current.beginning_of_week.iso8601
    PlanPersonalizado.find_each do |plan|
      rutina = plan.rutina
      # Idempotencia: lo ya migrado no se toca.
      next ya_v2 += 1 if rutina.is_a?(Hash) && rutina["version"].to_i >= PlanPersonalizado::VERSION_MESOCICLO
      # Un plan generando/fallido sin días aún no tiene nada que envolver.
      next sin_rutina += 1 if !rutina.is_a?(Hash) || rutina["dias"].blank?

      nueva = rutina.merge(
        "version" => PlanPersonalizado::VERSION_MESOCICLO,
        "mesociclo" => { "nombre" => "Mesociclo 1", "semanas_total" => SEMANAS_POR_DEFECTO,
                         "inicio" => inicio, "progresion" => "lineal" },
        "semanas" => (1..SEMANAS_POR_DEFECTO).map do |numero|
          { "numero" => numero, "etiqueta" => "Semana #{numero}", "descarga" => false,
            "ajuste" => { "series_delta" => 0, "peso_factor" => 1.0, "reps_delta" => 0 },
            "dias" => nil }
        end
      )
      # update_columns: backfill masivo sin callbacks (evita una tormenta de
      # broadcasts Turbo) ni validaciones — solo se agregan claves al jsonb.
      plan.update_columns(rutina: nueva, updated_at: Time.current) if aplicar
      migrados += 1
    end

    puts
    puts "═══ Reporte ═══"
    puts "  Planes totales:        #{PlanPersonalizado.count}"
    puts "  Migrados#{aplicar ? ":            " : " (dry-run):  "} #{migrados}"
    puts "  Ya en v2 (saltados):   #{ya_v2}"
    puts "  Sin rutina (saltados): #{sin_rutina}"
    puts "  ⚠ Nada se escribió: vuelve a correr con APLICAR=1" unless aplicar
  end

  desc "Revierte el contrato v2 a v1 (lossless si nada materializado; FORZAR=1 descarta materializadas)"
  task revertir: :environment do
    mesociclo_guardia_supabase!
    aplicar = ENV["APLICAR"] == "1"
    forzar = ENV["FORZAR"] == "1"
    puts aplicar ? "═══ Reversión rutina v2 → v1 (ESCRIBIENDO) ═══" :
                   "═══ Reversión rutina v2 → v1 (dry-run; APLICAR=1 para escribir) ═══"

    revertidos = ya_v1 = con_materializadas = 0
    PlanPersonalizado.find_each do |plan|
      rutina = plan.rutina
      next ya_v1 += 1 unless rutina.is_a?(Hash) && rutina["version"].to_i >= PlanPersonalizado::VERSION_MESOCICLO

      materializadas = Array(rutina["semanas"]).count { |sem| !sem["dias"].nil? }
      if materializadas.positive? && !forzar
        con_materializadas += 1
        puts "  ⚠ Plan ##{plan.id}: #{materializadas} semana(s) materializada(s) — saltado " \
             "(revertirlo con FORZAR=1 descartaría esas ediciones)"
        next
      end

      v1 = rutina.except("version", "mesociclo", "semanas")
      plan.update_columns(rutina: v1, updated_at: Time.current) if aplicar
      revertidos += 1
    end

    puts
    puts "═══ Reporte ═══"
    puts "  Planes totales:            #{PlanPersonalizado.count}"
    puts "  Revertidos#{aplicar ? ":              " : " (dry-run):    "} #{revertidos}"
    puts "  Ya en v1 (saltados):       #{ya_v1}"
    puts "  Con materializadas:        #{con_materializadas}#{con_materializadas.positive? && !forzar ? " (saltados — FORZAR=1 para incluirlos)" : ""}"
    puts "  ⚠ Nada se escribió: vuelve a correr con APLICAR=1" unless aplicar
  end
end
