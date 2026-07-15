require "rails_helper"

RSpec.describe NovedadPolicy do
  describe "#admin_index?" do
    it "niega a un miembro" do
      expect(described_class.new(users(:one), Novedad)).not_to be_admin_index
    end

    it "permite al entrenador" do
      expect(described_class.new(users(:entrenador), Novedad)).to be_admin_index
    end
  end

  describe "#create?" do
    it "niega a un miembro" do
      expect(described_class.new(users(:one), Novedad)).not_to be_create
    end
  end
end
