class AddVipAUsuarios < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :vip, :boolean, null: false, default: false
  end
end
