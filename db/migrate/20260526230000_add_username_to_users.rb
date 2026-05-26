class AddUsernameToUsers < ActiveRecord::Migration[8.1]
  class MigrationUser < ApplicationRecord
    self.table_name = "users"
  end

  def up
    add_column :users, :username, :string

    MigrationUser.reset_column_information

    existing = {}
    MigrationUser.find_each do |user|
      base = user.email.to_s.split("@").first.to_s.downcase.gsub(/[^a-z0-9_]/, "")
      base = "user" if base.blank?

      candidate = base
      suffix = 1
      while existing[candidate] || MigrationUser.where.not(id: user.id).exists?(username: candidate)
        suffix += 1
        candidate = "#{base}#{suffix}"
      end

      existing[candidate] = true
      user.update_columns(username: candidate)
    end

    change_column_null :users, :username, false
    add_index :users, :username, unique: true
  end

  def down
    remove_index :users, :username
    remove_column :users, :username
  end
end
