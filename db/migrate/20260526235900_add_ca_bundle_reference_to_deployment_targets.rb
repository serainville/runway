class AddCaBundleReferenceToDeploymentTargets < ActiveRecord::Migration[8.1]
  def change
    add_column :deployment_targets, :ca_bundle_reference, :string, null: false, default: ""
  end
end
