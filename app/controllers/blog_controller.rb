class BlogController < ApplicationController
  def index
    authorize Post
    # policy_scope: solo posts del tenant propio (Fase 18f).
    @posts = policy_scope(Post).publicados
  end

  def show
    @post = policy_scope(Post).find_by!(slug: params[:id])
    authorize @post
    # ETag condicional (Fase de Calidad): si el post no cambió, el navegador
    # recibe 304 y el servidor se ahorra el re-render.
    fresh_when @post
  end
end
