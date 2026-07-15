require "rails_helper"

RSpec.describe PostPolicy do
  let(:publicado) { Post.create!(autor: users(:admin), titulo: "Publicado", contenido: "x", publicado: true, publicado_en: Time.current) }
  let(:borrador) { Post.create!(autor: users(:admin), titulo: "Borrador", contenido: "x") }

  describe "#show?" do
    it "un miembro ve un post publicado" do
      expect(described_class.new(users(:one), publicado)).to be_show
    end

    it "un miembro no ve un borrador" do
      expect(described_class.new(users(:one), borrador)).not_to be_show
    end

    it "el staff ve borradores" do
      expect(described_class.new(users(:admin), borrador)).to be_show
    end
  end

  describe "#create?" do
    it "niega a un miembro" do
      expect(described_class.new(users(:one), Post)).not_to be_create
    end

    it "permite al entrenador" do
      expect(described_class.new(users(:entrenador), Post)).to be_create
    end
  end
end
