class BlogController < ApplicationController
  def index
    authorize Post
    @posts = Post.publicados
  end

  def show
    @post = Post.find_by!(slug: params[:id])
    authorize @post
    # ETag condicional (Fase de Calidad): si el post no cambió, el navegador
    # recibe 304 y el servidor se ahorra el re-render.
    fresh_when @post
  end
end
