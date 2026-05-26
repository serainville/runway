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

ActiveRecord::Schema[8.0].define(version: 2026_05_26_134917) do
  create_table "applications", force: :cascade do |t|
    t.integer "team_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id", "name"], name: "index_applications_on_team_id_and_name", unique: true
    t.index ["team_id", "slug"], name: "index_applications_on_team_id_and_slug", unique: true
    t.index ["team_id"], name: "index_applications_on_team_id"
  end

  create_table "audit_events", force: :cascade do |t|
    t.integer "team_id", null: false
    t.integer "actor_id", null: false
    t.string "action", null: false
    t.string "auditable_type"
    t.integer "auditable_id"
    t.json "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_audit_events_on_actor_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable"
    t.index ["occurred_at"], name: "index_audit_events_on_occurred_at"
    t.index ["team_id"], name: "index_audit_events_on_team_id"
  end

  create_table "deployment_targets", force: :cascade do |t|
    t.string "name", null: false
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_deployment_targets_on_name", unique: true
  end

  create_table "environments", force: :cascade do |t|
    t.integer "application_id", null: false
    t.string "name", null: false
    t.boolean "default", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["application_id", "name"], name: "index_environments_on_application_id_and_name", unique: true
    t.index ["application_id"], name: "index_environments_on_application_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "team_id", null: false
    t.string "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id"], name: "index_memberships_on_team_id"
    t.index ["user_id", "team_id"], name: "index_memberships_on_user_id_and_team_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_teams_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "applications", "teams"
  add_foreign_key "audit_events", "teams"
  add_foreign_key "audit_events", "users", column: "actor_id"
  add_foreign_key "environments", "applications"
  add_foreign_key "memberships", "teams"
  add_foreign_key "memberships", "users"
end
