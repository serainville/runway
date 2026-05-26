class AddRuntimeDetailsToApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :applications, :runtime_version, :string
    add_reference :applications, :runtime_option, foreign_key: true
  end
end
