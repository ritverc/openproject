# frozen_string_literal: true

class AddWorkPackageRoleConditionToCustomActions < ActiveRecord::Migration[7.1]
  def change
    add_column :custom_actions, :work_package_role_condition, :text, null: true
  end
end
