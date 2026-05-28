class AddWebhookPolicyFieldsToApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :applications, :webhook_branch_filter, :string, default: "", null: false
    add_column :applications, :webhook_event_policy, :string, default: "merge_only", null: false

    add_index :applications, :webhook_event_policy
  end
end
