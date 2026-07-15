require "rails_helper"

RSpec.describe Post, type: :model do
  it "genera el slug a partir del título si no se da uno" do
    post = Post.create!(autor: users(:admin), titulo: "Cinco tips de nutrición", contenido: "hola")
    expect(post.slug).to eq("cinco-tips-de-nutricion")
  end

  it "respeta un slug explícito" do
    post = Post.create!(autor: users(:admin), titulo: "Título", slug: "mi-slug", contenido: "hola")
    expect(post.slug).to eq("mi-slug")
  end

  it "no permite slugs duplicados" do
    Post.create!(autor: users(:admin), titulo: "Uno", slug: "duplicado", contenido: "hola")
    otro = Post.new(autor: users(:admin), titulo: "Dos", slug: "duplicado", contenido: "hola")
    expect(otro).not_to be_valid
  end

  it "publicar! marca publicado y fija publicado_en" do
    post = Post.create!(autor: users(:admin), titulo: "Título", contenido: "hola")
    post.publicar!
    expect(post.publicado?).to be true
    expect(post.publicado_en).to be_present
  end

  describe ".publicados" do
    it "incluye solo los publicados" do
      publicado = Post.create!(autor: users(:admin), titulo: "Publicado", contenido: "x", publicado: true, publicado_en: Time.current)
      Post.create!(autor: users(:admin), titulo: "Borrador", contenido: "x")

      expect(Post.publicados).to contain_exactly(publicado)
    end
  end
end
