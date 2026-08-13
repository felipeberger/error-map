class CreatePayloads < ActiveRecord::Migration[8.1]
  def change
    create_table :payloads do |t|
      t.references :error_event, null: false, foreign_key: true, index: { unique: true }
      t.string :content_type
      t.jsonb :body, default: {}
      t.string :param_fingerprint

      t.timestamps
    end

    add_index :payloads, :param_fingerprint
  end
end
