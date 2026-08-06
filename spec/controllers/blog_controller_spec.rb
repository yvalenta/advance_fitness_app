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

  # Fase 18f: el blog pasa por policy_scope — un post de otro tenant no se
  # lista ni se abre por slug, aunque esté publicado.
  it "no muestra ni abre posts de otro tenant" do
    admin_mp = User.create!(email_address: "admin-mp@x.com", password: "clave1234",
                            rol: "admin", tenant: tenants(:megaplex), nombre: "Admin MP")
    ajeno = Post.create!(autor: admin_mp, titulo: "Post ajeno", contenido: "x",
                         publicado: true, publicado_en: Time.current)
    sign_in_as users(:one)

    get blog_path
    expect(response.body).not_to include("Post ajeno")

    get blog_post_path(ajeno.slug)
    expect(response).to have_http_status(:not_found)
  end
end
