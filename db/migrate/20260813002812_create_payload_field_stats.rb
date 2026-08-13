class CreatePayloadFieldStats < ActiveRecord::Migration[8.1]
  def change
    create_table :payload_field_stats do |t|
      t.references :route, null: false, foreign_key: true
      t.string :field_path, null: false
      t.string :anomaly_type, null: false
      t.integer :error_count, null: false, default: 0
      t.decimal :error_rate, precision: 5, scale: 4, default: 0.0
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :payload_field_stats, [:route_id, :field_path, :anomaly_type],
      unique: true, name: "index_field_stats_on_route_field_anomaly"
  end
end
