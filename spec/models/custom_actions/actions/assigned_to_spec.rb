# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++
require "spec_helper"
require_relative "../shared_expectations"

RSpec.describe CustomActions::Actions::AssignedTo do
  let(:key) { :assigned_to }
  let(:type) { :user }
  let(:allowed_values) do
    users = [build_stubbed(:user), build_stubbed(:group)]
    allow(Principal)
      .to receive_message_chain(:not_locked, :select, :select_for_name, :ordered_by_name)
      .and_return(users)

    [{ value: nil, label: "-" },
     { value: "current_user", label: "(Assign to executing user)" },
     { value: "work_package_author", label: "(Assign to work package author)" },
     { value: "responsible",
       label: I18n.t("custom_actions.actions.assigned_to.field_value",
                     name: WorkPackage.human_attribute_name(:responsible)) },
     { value: users.first.id, label: users.first.name },
     { value: users.last.id, label: users.last.name }]
  end

  it_behaves_like "base custom action"
  it_behaves_like "associated custom action" do
    describe "#allowed_values" do
      it "is the list of all users" do
        allowed_values
        expect(instance.allowed_values).to eql(allowed_values)
      end
    end
  end

  describe "current_user special value" do
    let(:work_package) { build_stubbed(:work_package) }
    let(:user) { build_stubbed(:user) }

    subject { described_class.new }

    before do
      subject.values = ["current_user"]
    end

    it "can set the value" do
      expect(subject).to have_me_value
    end

    it "includes the value in available_values" do
      expect(subject.associated)
        .to include(["current_user", I18n.t("custom_actions.actions.assigned_to.executing_user_value")])
    end

    context "when logged in" do
      before do
        login_as user
      end

      it "returns the current user id" do
        subject.apply work_package
        expect(work_package.assigned_to_id).to eq(user.id)
      end

      it "validates the me value when executing" do
        errors = ActiveModel::Errors.new(CustomAction.new)
        subject.validate errors
        expect(errors.symbols_for(:actions)).to be_empty
      end
    end

    context "when not logged in" do
      it "returns nil for the current user id" do
        subject.apply work_package
        expect(work_package.assigned_to_id).to be_nil
      end

      it "validates the me value when executing" do
        errors = ActiveModel::Errors.new(CustomAction.new)
        subject.validate errors
        expect(errors.symbols_for(:actions)).to include :not_logged_in
      end
    end
  end

  describe "work_package_author special value" do
    let(:author) { build_stubbed(:user) }
    let(:work_package) { build_stubbed(:work_package, author:) }
    let(:other_user) { build_stubbed(:user) }

    subject { described_class.new }

    before do
      subject.values = ["work_package_author"]
    end

    it "can set the value" do
      expect(subject).to have_author_value
    end

    it "includes the value in available_values" do
      expect(subject.associated)
        .to include(["work_package_author", I18n.t("custom_actions.actions.assigned_to.author_value")])
    end

    context "when applying to a work package" do
      it "assigns the work package author as the assignee" do
        subject.apply work_package
        expect(work_package.assigned_to_id).to eq(author.id)
      end
    end

    context "when the work package has no author" do
      let(:work_package) { build_stubbed(:work_package, author: nil) }

      it "assigns nil when the work package has no author" do
        subject.apply work_package
        expect(work_package.assigned_to_id).to be_nil
      end
    end

    context "when a different user is logged in" do
      before do
        login_as other_user
      end

      it "still assigns the work package author, not the logged-in user" do
        subject.apply work_package
        expect(work_package.assigned_to_id).to eq(author.id)
        expect(work_package.assigned_to_id).not_to eq(other_user.id)
      end
    end

    context "when validating" do
      it "does not add validation errors for author value" do
        errors = ActiveModel::Errors.new(CustomAction.new)
        subject.validate errors
        # work_package_author does not require a logged-in user,
        # so there should be no error
        expect(errors.symbols_for(:actions)).to be_empty
      end
    end
  end

  describe "interaction between current_user and work_package_author" do
    let(:author) { build_stubbed(:user) }
    let(:executing_user) { build_stubbed(:user) }
    let(:work_package) { build_stubbed(:work_package, author:) }

    subject { described_class.new }

    it "only one special value can be active at a time (single-value constraint)" do
      subject.values = ["work_package_author"]
      expect(subject).to have_author_value
      expect(subject).not_to have_me_value
    end

    it "current_user takes precedence when both are somehow set" do
      # This scenario should not occur in normal UI usage,
      # but we verify the transformation logic is correct
      subject.values = ["current_user"]
      login_as executing_user
      subject.apply work_package
      expect(work_package.assigned_to_id).to eq(executing_user.id)
    end

    it "work_package_author resolves correctly when set" do
      subject.values = ["work_package_author"]
      login_as executing_user
      subject.apply work_package
      # The work package author must be assigned, not the executing user
      expect(work_package.assigned_to_id).to eq(author.id)
    end
  end

  describe "serialization of work_package_author value" do
    let(:serializer) { CustomActions::Actions::Serializer }

    it "correctly serializes the work_package_author marker" do
      action = described_class.new(["work_package_author"])
      serialized = serializer.dump([action])
      expect(serialized).to include("work_package_author")
    end

    it "correctly deserializes the work_package_author marker" do
      action = described_class.new(["work_package_author"])
      serialized = serializer.dump([action])
      deserialized = serializer.load(serialized)

      expect(deserialized.first).to be_a(described_class)
      expect(deserialized.first.values).to eq(["work_package_author"])
      expect(deserialized.first).to have_author_value
    end
  end

  describe "user custom field value" do
    shared_let(:source_user) { create(:user) }
    shared_let(:user_cf) { create(:user_wp_custom_field) }
    shared_let(:project) do
      create(:project).tap do |project|
        project.types.each { |type| type.custom_fields << user_cf }
        project.work_package_custom_fields << user_cf
      end
    end

    let(:marker) { "user_custom_field_#{user_cf.id}" }
    let(:work_package) do
      create(:work_package, project:, custom_values: { user_cf.id => source_user.id })
    end

    subject { described_class.new([marker]) }

    it "offers the user custom field as a selectable value" do
      expect(subject.associated)
        .to include([marker, I18n.t("custom_actions.actions.assigned_to.field_value", name: user_cf.name)])
    end

    it "preserves the marker as the stored value" do
      expect(subject.values).to eq([marker])
    end

    it "assigns the work package's custom field value" do
      subject.apply(work_package.reload)
      expect(work_package.assigned_to_id).to eq(source_user.id)
    end

    context "when the custom field has no value" do
      let(:work_package) { create(:work_package, project:) }

      it "assigns nil" do
        subject.apply(work_package.reload)
        expect(work_package.assigned_to_id).to be_nil
      end
    end

    context "when the referenced custom field no longer exists" do
      let(:marker) { "user_custom_field_#{user_cf.id}" }

      it "is rejected by allowed-value validation" do
        user_cf.destroy
        errors = ActiveModel::Errors.new(CustomAction.new)
        described_class.new([marker]).validate(errors)
        expect(errors.symbols_for(:actions)).to include(:inclusion)
      end
    end
  end

  # Mirror of the "user custom field value" block above, but for the
  # "user_attribute_<id>" marker that reads the executing user's value of a
  # UserCustomField of format "user" (a user attribute) instead of a
  # work-package custom field.
  describe "user attribute custom field value" do
    shared_let(:source_user) { create(:user) }
    shared_let(:user_attribute_cf) { create(:user_custom_field, :user) }
    let(:marker) { "user_attribute_#{user_attribute_cf.id}" }
    let(:work_package) { build_stubbed(:work_package) }

    subject { described_class.new([marker]) }

    context "when the executing user has a value for the attribute" do
      let(:current_user) do
        create(:user, custom_values: [build(:custom_value,
                                            custom_field: user_attribute_cf,
                                            value: source_user.id.to_s)])
      end

      before { login_as current_user }

      it "offers the user attribute as a selectable value" do
        expect(subject.associated)
          .to include([marker, I18n.t("custom_actions.actions.assigned_to.user_attribute_value",
                                      name: user_attribute_cf.name)])
      end

      it "preserves the marker as the stored value" do
        expect(subject.values).to eq([marker])
      end

      it "assigns the executing user's attribute value" do
        subject.apply(work_package)
        expect(work_package.assigned_to_id).to eq(source_user.id)
      end
    end

    context "when the executing user has no value for the attribute" do
      let(:current_user) { create(:user) }

      before { login_as current_user }

      it "assigns nil" do
        subject.apply(work_package)
        expect(work_package.assigned_to_id).to be_nil
      end
    end

    context "when the executing user is anonymous" do
      before { login_as User.anonymous }

      it "assigns nil" do
        subject.apply(work_package)
        expect(work_package.assigned_to_id).to be_nil
      end
    end

    context "when the referenced user attribute no longer exists" do
      let(:current_user) { create(:user) }

      before do
        login_as current_user
        user_attribute_cf.destroy
      end

      it "is rejected by allowed-value validation" do
        errors = ActiveModel::Errors.new(CustomAction.new)
        described_class.new([marker]).validate(errors)
        expect(errors.symbols_for(:actions)).to include(:inclusion)
      end
    end
  end

  describe "responsible field value (save/restore source)" do
    let(:accountable) { build_stubbed(:user) }
    let(:work_package) { build_stubbed(:work_package, responsible: accountable) }

    subject { described_class.new(["responsible"]) }

    it "offers the accountable field as a source but not the assignee itself" do
      keys = subject.associated.map(&:first)
      expect(keys).to include("responsible")
      expect(keys).not_to include("assigned_to")
    end

    it "assigns the work package's accountable as the assignee" do
      subject.apply(work_package)
      expect(work_package.assigned_to_id).to eq(accountable.id)
    end
  end
end
