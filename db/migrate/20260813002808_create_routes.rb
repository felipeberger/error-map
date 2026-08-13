class CreateRoutes < ActiveRecord::Migration[8.1]
  def change
    create_table :routes do |t|
      t.string :path, null: false
      t.string :http_method, null: false
      t.string :service
      t.string :environment

      t.timestamps
    end

    add_index :routes, [ :path, :http_method, :service, :environment ],
      unique: true, name: "index_routes_on_identity"
  end
end
