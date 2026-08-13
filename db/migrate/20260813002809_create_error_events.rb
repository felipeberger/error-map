class CreateErrorEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :error_events do |t|
      t.references :route, null: false, foreign_key: true
      t.string :datadog_event_id, null: false
      t.datetime :occurred_at, null: false
      t.integer :status_code
      t.string :error_class
      t.text :message

      t.timestamps
    end

    add_index :error_events, :datadog_event_id, unique: true
    add_index :error_events, :occurred_at
  end
end
