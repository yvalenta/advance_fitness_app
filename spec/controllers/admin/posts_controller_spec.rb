require "rails_helper"

RSpec.describe "Admin::Posts", type: :request do
  it "un miembro no accede" do
    sign_in_as users(:one)
    get admin_posts_path
    expect(response).to redirect_to(root_path)
  end

  it "el entrenador crea un post como borrador" do
    sign_in_as users(:entrenador)

    expect {
      post admin_posts_path, params: { post: { titulo: "Mi post", contenido: "hola" } }
    }.to change(Post, :count).by(1)

    creado = Post.last
    expect(creado.autor).to eq(users(:entrenador))
    expect(creado.publicado?).to be false
  end

  it "publicar marca el post como publicado" do
    sign_in_as users(:admin)
    post_creado = Post.create!(autor: users(:admin), titulo: "Título", contenido: "x")

    post publicar_admin_post_path(post_creado)

    expect(post_creado.reload.publicado?).to be true
  end
end
