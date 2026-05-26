class AddBackendFieldsToDeploymentTargets < ActiveRecord::Migration[8.1]
  def change
    add_column :deployment_targets, :backend_type, :string, null: false, default: "kubernetes"
    add_column :deployment_targets, :endpoint, :string, null: false, default: "https://unconfigured.local"
    add_column :deployment_targets, :credential_reference, :string, null: false, default: ""
    add_column :deployment_targets, :validation_status, :string, null: false, default: "pending"
    add_column :deployment_targets, :active, :boolean, null: false, default: true

    add_index :deployment_targets, :backend_type
    add_index :deployment_targets, :active
  end
end
