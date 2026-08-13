# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_13_002812) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "error_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "datadog_event_id", null: false
    t.string "error_class"
    t.text "message"
    t.datetime "occurred_at", null: false
    t.bigint "route_id", null: false
    t.integer "status_code"
    t.datetime "updated_at", null: false
    t.index ["datadog_event_id"], name: "index_error_events_on_datadog_event_id", unique: true
    t.index ["occurred_at"], name: "index_error_events_on_occurred_at"
    t.index ["route_id"], name: "index_error_events_on_route_id"
  end

  create_table "payload_field_stats", force: :cascade do |t|
    t.string "anomaly_type", null: false
    t.datetime "created_at", null: false
    t.integer "error_count", default: 0, null: false
    t.decimal "error_rate", precision: 5, scale: 4, default: "0.0"
    t.string "field_path", null: false
    t.datetime "last_seen_at"
    t.bigint "route_id", null: false
    t.datetime "updated_at", null: false
    t.index ["route_id", "field_path", "anomaly_type"], name: "index_field_stats_on_route_field_anomaly", unique: true
    t.index ["route_id"], name: "index_payload_field_stats_on_route_id"
  end

  create_table "payloads", force: :cascade do |t|
    t.jsonb "body", default: {}
    t.string "content_type"
    t.datetime "created_at", null: false
    t.bigint "error_event_id", null: false
    t.string "param_fingerprint"
    t.datetime "updated_at", null: false
    t.index ["error_event_id"], name: "index_payloads_on_error_event_id", unique: true
    t.index ["param_fingerprint"], name: "index_payloads_on_param_fingerprint"
  end

  create_table "routes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "environment"
    t.string "http_method", null: false
    t.string "path", null: false
    t.string "service"
    t.datetime "updated_at", null: false
    t.index ["path", "http_method", "service", "environment"], name: "index_routes_on_identity", unique: true
  end

  add_foreign_key "error_events", "routes"
  add_foreign_key "payload_field_stats", "routes"
  add_foreign_key "payloads", "error_events"
end
