class AddDeploymentTargetToEnvironments < ActiveRecord::Migration[8.1]
  class MigrationEnvironment < ActiveRecord::Base
    self.table_name = "environments"
  end

  class MigrationDeploymentTarget < ActiveRecord::Base
    self.table_name = "deployment_targets"
  end

  def up
    add_reference :environments, :deployment_target, foreign_key: true, null: true

    default_target = MigrationDeploymentTarget.find_or_create_by!(name: "tenant-nonp") do |target|
      target.description = "Default tenant non-production target"
    end

    MigrationEnvironment.where(deployment_target_id: nil).update_all(deployment_target_id: default_target.id)

    change_column_null :environments, :deployment_target_id, false
  end

  def down
    remove_reference :environments, :deployment_target, foreign_key: true
  end
end
