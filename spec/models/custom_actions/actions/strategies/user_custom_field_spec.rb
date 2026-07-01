# frozen_string_literal: true

#-- copyright
#++

require "spec_helper"

module CustomActions
  module Actions
    module Strategies
      RSpec.describe UserCustomField do
        shared_let(:role) do
          create(:project_role, permissions: %i[view_work_packages view_projects edit_work_packages])
        end
        shared_let(:user_cf) { create(:user_wp_custom_field) }
        shared_let(:multi_user_cf) { create(:multi_user_wp_custom_field) }
        shared_let(:users) { create_list(:user, 5) }
        shared_let(:single_user_project) do
          create(:project, members: [[users[0], role]]).tap do |project|
            [user_cf, multi_user_cf].each do |cf|
              project.types.each { it.custom_fields << cf }
              project.work_package_custom_fields << cf
            end
          end
        end
        shared_let(:multi_user_project) do
          create(:project, members: users[0..3].map { [it, role] }).tap do |project|
            [user_cf, multi_user_cf].each do |cf|
              project.work_package_custom_fields << cf
            end
          end
        end

        let(:user_cf_action) { CustomActions::Actions::CustomField.for("custom_field_#{user_cf.id}").new }
        let(:multi_user_cf_action) { CustomActions::Actions::CustomField.for("custom_field_#{multi_user_cf.id}").new }
        let(:single_user_work_package) { create(:work_package, project: single_user_project) }
        let(:multi_user_work_package) { create(:work_package, project: multi_user_project) }

        let(:custom_action) do
          create(:custom_action,
                 type_conditions: [single_user_work_package.type],
                 project_conditions: [single_user_project],
                 actions: [user_cf_action, multi_user_cf_action])
        end

        let(:user) { users[0] }

        context "when no users can be assigned to the single value custom field" do
          before do
            user_cf_action.values = users[4].id
            multi_user_cf_action.values = users[1..3].map(&:id)
            custom_action.save
          end

          it "fails with an error" do
            login_as user
            result = UpdateWorkPackageService.new(user:, action: custom_action)
                                             .call(work_package: single_user_work_package)

            expect(result).to be_failure
            expect(result.errors.size).to eq(1)

            updated = result.result.reload
            expect(updated.send("custom_field_#{multi_user_cf.id}")).to eq([nil])
            expect(updated.send("custom_field_#{user_cf.id}")).to be_nil
          end
        end

        context "when at least one user can be assigned to custom field" do
          before do
            user_cf_action.values = user.id
            multi_user_cf_action.values = users[0..3].map(&:id)
            custom_action.save
            login_as user
          end

          it "succeeds" do
            result = UpdateWorkPackageService.new(user:, action: custom_action).call(work_package: single_user_work_package)
            expect(result).to be_success

            multi_user_result = UpdateWorkPackageService.new(user:, action: custom_action)
                                                        .call(work_package: multi_user_work_package)

            expect(multi_user_result).to be_success
          end

          it "saves the custom field values on the work package" do
            result = UpdateWorkPackageService.new(user:, action: custom_action)
                                             .call(work_package: single_user_work_package)

            updated = result.result.reload
            expect(updated.send("custom_field_#{user_cf.id}")).to eq(user)
            expect(updated.send("custom_field_#{multi_user_cf.id}")).to eq([user])

            muti_user_result = UpdateWorkPackageService.new(user:, action: custom_action)
                                             .call(work_package: multi_user_work_package)

            updated = muti_user_result.result.reload
            expect(updated.send("custom_field_#{user_cf.id}")).to eq(user)
            expect(updated.send("custom_field_#{multi_user_cf.id}")).to eq(users[0..3])
          end
        end

        describe "handling of the 'me' values" do
          before do
            user_cf_action.values = "current_user"
            multi_user_cf_action.values = ["current_user"] + users[1..3].map(&:id)
            custom_action.save
            login_as user
          end

          it "assigns the current user to the custom field" do
            result = UpdateWorkPackageService.new(user:, action: custom_action)
                                             .call(work_package: single_user_work_package)

            updated = result.result.reload
            expect(updated.send("custom_field_#{user_cf.id}")).to eq(user)
            expect(updated.send("custom_field_#{multi_user_cf.id}")).to eq([user])
          end
        end

        # Unit-level (calls #apply directly) to stay independent of CustomAction
        # persistence, which is unrelated to this strategy.
        describe "user custom field value markers" do
          it "offers other user custom fields but excludes its own field" do
            keys = user_cf_action.associated.map(&:first)

            expect(keys).to include("user_custom_field_#{multi_user_cf.id}")
            expect(keys).not_to include("user_custom_field_#{user_cf.id}")
          end

          it "copies the value of another user custom field onto the field" do
            single_user_work_package.update(custom_field_values: { multi_user_cf.id => user.id })
            user_cf_action.values = "user_custom_field_#{multi_user_cf.id}"

            user_cf_action.apply(single_user_work_package)

            expect(single_user_work_package.send("custom_field_#{user_cf.id}")).to eq(user)
          end

          it "offers the work package assignee and accountable as sources" do
            keys = user_cf_action.associated.map(&:first)

            expect(keys).to include("assigned_to", "responsible")
          end

          it "copies the work package assignee onto the field" do
            single_user_work_package.update(assigned_to: user)
            user_cf_action.values = "assigned_to"

            user_cf_action.apply(single_user_work_package)

            expect(single_user_work_package.send("custom_field_#{user_cf.id}")).to eq(user)
          end
        end

        # The core of the "save & restore a person on status change" workflow: a
        # value source is always read from the *original* (pre-action) state, so
        # the order in which actions are applied does not change the result.
        describe "order independence (save & restore)" do
          it "saves the original assignee even when another action changes the assignee first" do
            single_user_work_package.update(assigned_to: users[0])
            change_assignee = CustomActions::Actions::AssignedTo.new([users[1].id])
            user_cf_action.values = "assigned_to"

            change_assignee.apply(single_user_work_package)
            user_cf_action.apply(single_user_work_package)

            expect(single_user_work_package.send("custom_field_#{user_cf.id}")).to eq(users[0])
          end

          it "restores the assignee from the original field value even when the field changes first" do
            single_user_work_package.update(custom_field_values: { user_cf.id => users[0].id })
            change_cf = CustomActions::Actions::CustomField.for("custom_field_#{user_cf.id}").new([users[1].id])
            restore_assignee = CustomActions::Actions::AssignedTo.new(["user_custom_field_#{user_cf.id}"])

            change_cf.apply(single_user_work_package)
            restore_assignee.apply(single_user_work_package)

            expect(single_user_work_package.assigned_to_id).to eq(users[0].id)
          end
        end
      end
    end
  end
end
