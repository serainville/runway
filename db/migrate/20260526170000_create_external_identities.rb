class CreateExternalIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :external_identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :external_subject, null: false
      t.json :metadata, null: false, default: {}
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :external_identities, [:provider, :external_subject], unique: true
    add_index :external_identities, [:user_id, :provider], unique: true
  end
end
