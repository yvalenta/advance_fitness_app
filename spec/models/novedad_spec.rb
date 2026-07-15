require "rails_helper"

RSpec.describe Novedad, type: :model do
  it "requiere título y contenido" do
    expect(Novedad.new).not_to be_valid
  end

  describe ".publicadas" do
    it "incluye solo las publicadas" do
      publicada = Novedad.create!(titulo: "Publicada", contenido: "x", publicado: true)
      Novedad.create!(titulo: "Borrador", contenido: "x")

      expect(Novedad.publicadas).to contain_exactly(publicada)
    end
  end
end
