class AddProjectOwnerInvariantTriggers < ActiveRecord::Migration[8.1]
  def up
    adapter = ActiveRecord::Base.connection.adapter_name.downcase

    if adapter.include?("sqlite")
      execute <<~SQL
        CREATE TRIGGER IF NOT EXISTS trg_project_memberships_prevent_last_owner_delete
        BEFORE DELETE ON project_memberships
        FOR EACH ROW
        WHEN OLD.role = 'owner'
         AND (SELECT COUNT(*) FROM project_memberships WHERE project_id = OLD.project_id AND role = 'owner') = 1
        BEGIN
          SELECT RAISE(ABORT, 'project must keep at least one owner');
        END;
      SQL

      execute <<~SQL
        CREATE TRIGGER IF NOT EXISTS trg_project_memberships_prevent_last_owner_demotion
        BEFORE UPDATE OF role ON project_memberships
        FOR EACH ROW
        WHEN OLD.role = 'owner'
         AND NEW.role <> 'owner'
         AND (SELECT COUNT(*) FROM project_memberships WHERE project_id = OLD.project_id AND role = 'owner') = 1
        BEGIN
          SELECT RAISE(ABORT, 'project must keep at least one owner');
        END;
      SQL
    elsif adapter.include?("mysql")
      execute <<~SQL
        CREATE TRIGGER trg_project_memberships_prevent_last_owner_delete
        BEFORE DELETE ON project_memberships
        FOR EACH ROW
        BEGIN
          IF OLD.role = 'owner' AND
             (SELECT COUNT(*) FROM project_memberships WHERE project_id = OLD.project_id AND role = 'owner') = 1 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'project must keep at least one owner';
          END IF;
        END;
      SQL

      execute <<~SQL
        CREATE TRIGGER trg_project_memberships_prevent_last_owner_demotion
        BEFORE UPDATE ON project_memberships
        FOR EACH ROW
        BEGIN
          IF OLD.role = 'owner' AND NEW.role <> 'owner' AND
             (SELECT COUNT(*) FROM project_memberships WHERE project_id = OLD.project_id AND role = 'owner') = 1 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'project must keep at least one owner';
          END IF;
        END;
      SQL
    end
  end

  def down
    adapter = ActiveRecord::Base.connection.adapter_name.downcase

    if adapter.include?("sqlite")
      execute "DROP TRIGGER IF EXISTS trg_project_memberships_prevent_last_owner_delete"
      execute "DROP TRIGGER IF EXISTS trg_project_memberships_prevent_last_owner_demotion"
    elsif adapter.include?("mysql")
      execute "DROP TRIGGER IF EXISTS trg_project_memberships_prevent_last_owner_delete"
      execute "DROP TRIGGER IF EXISTS trg_project_memberships_prevent_last_owner_demotion"
    end
  end
end
