class AddCurrentCommitShaToApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :applications, :current_commit_sha, :string
    add_index :applications, :current_commit_sha
  end
end