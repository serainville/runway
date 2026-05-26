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

ActiveRecord::Schema[8.1].define(version: 2026_05_26_200600) do
  create_table "applications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "project_id"
    t.string "runtime"
    t.integer "runtime_option_id"
    t.string "runtime_version"
    t.string "slug", null: false
    t.integer "team_id"
    t.datetime "updated_at", null: false
    t.index ["project_id", "name"], name: "index_applications_on_project_id_and_name", unique: true
    t.index ["project_id", "slug"], name: "index_applications_on_project_id_and_slug", unique: true
    t.index ["project_id"], name: "index_applications_on_project_id"
    t.index ["runtime_option_id"], name: "index_applications_on_runtime_option_id"
    t.index ["team_id", "name"], name: "index_applications_on_team_id_and_name", unique: true
    t.index ["team_id", "slug"], name: "index_applications_on_team_id_and_slug", unique: true
    t.index ["team_id"], name: "index_applications_on_team_id"
  end

  create_table "audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.integer "actor_id", null: false
    t.integer "auditable_id"
    t.string "auditable_type"
    t.datetime "created_at", null: false
    t.json "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.integer "team_id"
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_audit_events_on_actor_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable"
    t.index ["occurred_at"], name: "index_audit_events_on_occurred_at"
    t.index ["team_id"], name: "index_audit_events_on_team_id"
  end

  create_table "deployment_targets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_deployment_targets_on_name", unique: true
  end

  create_table "environments", force: :cascade do |t|
    t.integer "application_id", null: false
    t.datetime "created_at", null: false
    t.boolean "default", default: false, null: false
    t.integer "deployment_target_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["application_id", "name"], name: "index_environments_on_application_id_and_name", unique: true
    t.index ["application_id"], name: "index_environments_on_application_id"
    t.index ["deployment_target_id"], name: "index_environments_on_deployment_target_id"
  end

  create_table "external_identities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_subject", null: false
    t.datetime "last_synced_at"
    t.json "metadata", default: {}, null: false
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["provider", "external_subject"], name: "index_external_identities_on_provider_and_external_subject", unique: true
    t.index ["user_id", "provider"], name: "index_external_identities_on_user_id_and_provider", unique: true
    t.index ["user_id"], name: "index_external_identities_on_user_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "role", null: false
    t.integer "team_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["team_id"], name: "index_memberships_on_team_id"
    t.index ["user_id", "team_id"], name: "index_memberships_on_user_id_and_team_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "project_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "project_id", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["project_id", "user_id"], name: "index_project_memberships_on_project_id_and_user_id", unique: true
    t.index ["project_id"], name: "index_project_memberships_on_project_id"
    t.index ["user_id"], name: "index_project_memberships_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_projects_on_name", unique: true
    t.index ["slug"], name: "index_projects_on_slug", unique: true
  end

  create_table "repository_connections", force: :cascade do |t|
    t.integer "application_id", null: false
    t.datetime "created_at", null: false
    t.string "default_branch", null: false
    t.string "provider", null: false
    t.string "repo_url", null: false
    t.datetime "updated_at", null: false
    t.index ["application_id"], name: "index_repository_connections_on_application_id", unique: true
  end

  create_table "runtime_options", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "version", null: false
    t.index ["active"], name: "index_runtime_options_on_active"
    t.index ["name", "version"], name: "index_runtime_options_on_name_and_version", unique: true
  end

  create_table "teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_teams_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "applications", "projects"
  add_foreign_key "applications", "runtime_options"
  add_foreign_key "applications", "teams"
  add_foreign_key "audit_events", "teams"
  add_foreign_key "audit_events", "users", column: "actor_id"
  add_foreign_key "environments", "applications"
  add_foreign_key "environments", "deployment_targets"
  add_foreign_key "external_identities", "users"
  add_foreign_key "memberships", "teams"
  add_foreign_key "memberships", "users"
  add_foreign_key "project_memberships", "projects"
  add_foreign_key "project_memberships", "users"
  add_foreign_key "repository_connections", "applications"
end
