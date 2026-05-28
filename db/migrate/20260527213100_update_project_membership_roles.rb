class UpdateProjectMembershipRoles < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE project_memberships
      SET role = 'contributor'
      WHERE role = 'member'
    SQL

    add_check_constraint :project_memberships,
                         "role IN ('owner', 'contributor', 'reviewer')",
                         name: "chk_project_memberships_role"
  end

  def down
    remove_check_constraint :project_memberships, name: "chk_project_memberships_role"

    execute <<~SQL
      UPDATE project_memberships
      SET role = 'member'
      WHERE role = 'contributor'
    SQL
  end
end
