class NovedadesController < ApplicationController
  before_action { exigir_feature("novedades") }  # Fase 18d
  def index
    authorize Novedad
    # policy_scope: solo las del tenant propio (Fase 18f — la Scope existía
    # desde §16.6 pero el controller listaba global).
    @novedades = policy_scope(Novedad).publicadas
  end
end
