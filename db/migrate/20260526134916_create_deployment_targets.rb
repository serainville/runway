class CreateDeploymentTargets < ActiveRecord::Migration[8.0]
  def change
    create_table :deployment_targets do |t|
      t.string :name, null: false
      t.string :description

      t.timestamps
    end

    add_index :deployment_targets, :name, unique: true
  end
end
