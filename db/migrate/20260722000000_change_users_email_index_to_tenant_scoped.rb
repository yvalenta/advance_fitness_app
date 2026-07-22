class ChangeUsersEmailIndexToTenantScoped < ActiveRecord::Migration[8.1]
  def change
    remove_index :users, :email_address, unique: true, if_exists: true
    add_index :users, %i[email_address tenant_id], unique: true,
              name: "index_users_on_email_address_and_tenant_id"
  end
end
