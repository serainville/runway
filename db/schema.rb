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

ActiveRecord::Schema[8.1].define(version: 2026_05_27_201100) do
  create_table "applications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "current_commit_sha"
    t.text "description"
    t.string "name", null: false
    t.integer "project_id"
    t.integer "repository_connection_id"
    t.string "repository_url", default: "", null: false
    t.string "runtime"
    t.integer "runtime_option_id"
    t.string "runtime_version"
    t.string "slug", null: false
    t.integer "team_id"
    t.datetime "updated_at", null: false
    t.index ["current_commit_sha"], name: "index_applications_on_current_commit_sha"
    t.index ["project_id", "name"], name: "index_applications_on_project_id_and_name", unique: true
    t.index ["project_id", "slug"], name: "index_applications_on_project_id_and_slug", unique: true
    t.index ["project_id"], name: "index_applications_on_project_id"
    t.index ["repository_connection_id"], name: "index_applications_on_repository_connection_id"
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

  create_table "build_host_request_events", force: :cascade do |t|
    t.integer "build_id", null: false
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.string "error_code"
    t.text "error_message"
    t.string "request_method", null: false
    t.string "request_path", null: false
    t.integer "response_status_code", null: false
    t.boolean "success", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["build_id", "created_at"], name: "index_build_host_events_on_build_created"
    t.index ["build_id"], name: "index_build_host_request_events_on_build_id"
  end

  create_table "build_integrations", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "ca_bundle_reference", default: "", null: false
    t.datetime "created_at", null: false
    t.string "credential_reference", default: "", null: false
    t.boolean "default", default: false, null: false
    t.text "description"
    t.string "endpoint", null: false
    t.string "integration_type", default: "docker_host", null: false
    t.datetime "last_heartbeat_at"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "validation_status", default: "pending", null: false
    t.index ["active"], name: "index_build_integrations_on_active"
    t.index ["default"], name: "index_build_integrations_on_default"
    t.index ["default"], name: "index_build_integrations_single_default", unique: true, where: "\"default\" = 1"
    t.index ["integration_type"], name: "index_build_integrations_on_integration_type"
    t.index ["last_heartbeat_at"], name: "index_build_integrations_on_last_heartbeat_at"
    t.index ["name"], name: "index_build_integrations_on_name", unique: true
  end

  create_table "build_log_chunks", force: :cascade do |t|
    t.integer "build_id", null: false
    t.text "chunk", null: false
    t.datetime "created_at", null: false
    t.string "phase", null: false
    t.datetime "reported_at", null: false
    t.integer "sequence", null: false
    t.datetime "updated_at", null: false
    t.index ["build_id", "phase", "sequence"], name: "index_build_log_chunks_on_build_phase_sequence", unique: true
    t.index ["build_id"], name: "index_build_log_chunks_on_build_id"
  end

  create_table "build_phase_events", force: :cascade do |t|
    t.integer "build_id", null: false
    t.datetime "created_at", null: false
    t.string "failure_code"
    t.text "message"
    t.string "phase", null: false
    t.datetime "reported_at", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["build_id", "created_at"], name: "index_build_phase_events_on_build_id_and_created_at"
    t.index ["build_id", "phase"], name: "index_build_phase_events_on_build_id_and_phase"
    t.index ["build_id"], name: "index_build_phase_events_on_build_id"
  end

  create_table "builds", force: :cascade do |t|
    t.integer "application_id", null: false
    t.string "artifact_reference"
    t.integer "build_integration_id"
    t.boolean "cancel_requested", default: false, null: false
    t.string "commit_sha", default: "manual", null: false
    t.datetime "created_at", null: false
    t.text "error_summary"
    t.string "failure_code"
    t.datetime "finished_at"
    t.datetime "lease_expires_at"
    t.string "lease_id"
    t.integer "requested_by_id", null: false
    t.integer "retry_count", default: 0, null: false
    t.string "runtime_container_id"
    t.string "runtime_key", null: false
    t.string "runtime_status"
    t.string "source_ref", default: "main", null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.string "worker_id"
    t.index ["application_id", "created_at"], name: "index_builds_on_application_id_and_created_at"
    t.index ["application_id"], name: "index_builds_on_application_id"
    t.index ["build_integration_id"], name: "index_builds_on_build_integration_id"
    t.index ["lease_id"], name: "index_builds_on_lease_id", unique: true
    t.index ["requested_by_id"], name: "index_builds_on_requested_by_id"
    t.index ["runtime_container_id"], name: "index_builds_on_runtime_container_id"
    t.index ["status"], name: "index_builds_on_status"
  end

  create_table "deployment_targets", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "backend_type", default: "kubernetes", null: false
    t.string "ca_bundle_reference", default: "", null: false
    t.datetime "created_at", null: false
    t.string "credential_reference", default: "", null: false
    t.string "description"
    t.string "endpoint", default: "https://unconfigured.local", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "validation_status", default: "pending", null: false
    t.index ["active"], name: "index_deployment_targets_on_active"
    t.index ["backend_type"], name: "index_deployment_targets_on_backend_type"
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
    t.text "auth_secret_ciphertext", default: "", null: false
    t.string "auth_username", default: "", null: false
    t.text "ca_bundle", default: "", null: false
    t.datetime "created_at", null: false
    t.string "endpoint_url", default: "", null: false
    t.string "name", default: "", null: false
    t.integer "project_id"
    t.string "provider", null: false
    t.string "scope", default: "project", null: false
    t.datetime "updated_at", null: false
    t.string "validation_status", default: "pending", null: false
    t.index ["project_id"], name: "index_repository_connections_on_project_id"
    t.index ["scope", "project_id", "name"], name: "index_repository_connections_on_scope_project_and_name", unique: true
    t.index ["validation_status"], name: "index_repository_connections_on_validation_status"
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
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "applications", "projects"
  add_foreign_key "applications", "repository_connections"
  add_foreign_key "applications", "runtime_options"
  add_foreign_key "applications", "teams"
  add_foreign_key "audit_events", "teams"
  add_foreign_key "audit_events", "users", column: "actor_id"
  add_foreign_key "build_host_request_events", "builds"
  add_foreign_key "build_log_chunks", "builds"
  add_foreign_key "build_phase_events", "builds"
  add_foreign_key "builds", "applications"
  add_foreign_key "builds", "build_integrations"
  add_foreign_key "builds", "users", column: "requested_by_id"
  add_foreign_key "environments", "applications"
  add_foreign_key "environments", "deployment_targets"
  add_foreign_key "external_identities", "users"
  add_foreign_key "memberships", "teams"
  add_foreign_key "memberships", "users"
  add_foreign_key "project_memberships", "projects"
  add_foreign_key "project_memberships", "users"
  add_foreign_key "repository_connections", "projects"
end
