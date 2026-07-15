class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.references :autor, null: false, foreign_key: { to_table: :users }
      t.string :titulo, null: false
      t.string :slug, null: false
      t.boolean :publicado, null: false, default: false
      t.datetime :publicado_en

      t.timestamps
    end
    add_index :posts, :slug, unique: true
  end
end
