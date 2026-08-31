require "rails_helper"

RSpec.describe CambioOrganizacion, type: :model do
  let(:user) { users(:one) }

  def registrar(**atributos)
    CambioOrganizacion.create!({ user: user, de_tenant: tenants(:advance_fitness),
                                 a_tenant: tenants(:megaplex), ip: "127.0.0.1",
                                 user_agent: "spec" }.merge(atributos))
  end

  it "persiste el salto, con de_tenant nullable (portal comercial → tenant)" do
    fila = registrar(de_tenant: nil)
    expect(fila).to be_persisted
    expect(fila.de_tenant).to be_nil
    expect(fila.a_tenant).to eq tenants(:megaplex)
  end

  it "es append-only: una fila persistida no se edita ni se borra" do
    fila = registrar

    expect { fila.update!(ip: "10.0.0.1") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { fila.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect(CambioOrganizacion.count).to eq 1
  end

  it "token_digest es único (el pase es de UN SOLO USO) y nil no choca con nil" do
    registrar(token_digest: "abc123")
    expect { registrar(token_digest: "abc123") }.to raise_error(ActiveRecord::RecordNotUnique)

    # Filas de auditoría sin pase (p. ej. superadmin entrando) conviven.
    expect { registrar(token_digest: nil) }.not_to raise_error
    expect { registrar(token_digest: nil) }.not_to raise_error
  end
end
