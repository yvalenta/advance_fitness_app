require "rails_helper"

RSpec.describe "Blog", type: :request do
  it "un miembro solo ve posts publicados en el índice" do
    publicado = Post.create!(autor: users(:admin), titulo: "Publicado", contenido: "x", publicado: true, publicado_en: Time.current)
    Post.create!(autor: users(:admin), titulo: "Borrador", contenido: "x")
    sign_in_as users(:one)

    get blog_path

    expect(response.body).to include(publicado.titulo)
    expect(response.body).not_to include("Borrador")
  end

  it "un miembro no puede abrir un post en borrador" do
    borrador = Post.create!(autor: users(:admin), titulo: "Borrador", contenido: "x")
    sign_in_as users(:one)

    get blog_post_path(borrador.slug)

    expect(response).to redirect_to(root_path)
  end

  it "el staff sí puede previsualizar un borrador" do
    borrador = Post.create!(autor: users(:admin), titulo: "Borrador", contenido: "x")
    sign_in_as users(:admin)

    get blog_post_path(borrador.slug)

    expect(response).to have_http_status(:success)
  end
end
