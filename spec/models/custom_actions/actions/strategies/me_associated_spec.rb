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

RSpec.describe CustomActions::Actions::Strategies::MeAssociated do
  # Build a test class including the strategy for isolated testing
  let(:test_action_class) do
    Class.new(CustomActions::Actions::Base) do
      include CustomActions::Actions::Strategies::MeAssociated

      def self.key
        :test_action
      end

      def human_name
        "Test action"
      end

      def type
        :user
      end

      def apply(work_package)
        work_package.test_field_id = transformed_value_with_wp(values.first, work_package)
      end

      def available_principles
        []
      end
    end
  end

  subject { test_action_class.new }

  describe "#author_value_key" do
    it 'returns "work_package_author"' do
      expect(subject.author_value_key).to eq("work_package_author")
    end
  end

  describe "#author_name" do
    it "returns the i18n translation for the author value" do
      expect(subject.author_name).to eq(I18n.t("custom_actions.actions.assigned_to.author_value"))
    end
  end

  describe "#author_value" do
    it "returns a pair of [key, name]" do
      expect(subject.author_value).to eq([
                                           "work_package_author",
                                           I18n.t("custom_actions.actions.assigned_to.author_value")
                                         ])
    end
  end

  describe "#associated" do
    it "includes both current_user and work_package_author special values" do
      associated = subject.associated
      keys = associated.map(&:first)
      expect(keys).to include("current_user")
      expect(keys).to include("work_package_author")
    end

    it "lists current_user before work_package_author" do
      associated = subject.associated
      keys = associated.map(&:first)
      expect(keys.index("current_user")).to be < keys.index("work_package_author")
    end
  end

  describe "#values=" do
    it "preserves the work_package_author string marker" do
      subject.values = ["work_package_author"]
      expect(subject.values).to eq(["work_package_author"])
    end

    it "preserves the current_user string marker" do
      subject.values = ["current_user"]
      expect(subject.values).to eq(["current_user"])
    end

    it "converts numeric values to integers" do
      subject.values = ["42"]
      expect(subject.values).to eq([42])
    end

    it "handles mixed values correctly" do
      subject.values = ["work_package_author", "42", "current_user"]
      # uniq keeps all three since they are distinct
      expect(subject.values).to include("work_package_author", "current_user", 42)
    end
  end

  describe "#has_author_value?" do
    context "when work_package_author is set" do
      before { subject.values = ["work_package_author"] }

      it "returns true" do
        expect(subject.has_author_value?).to be true
      end
    end

    context "when current_user is set" do
      before { subject.values = ["current_user"] }

      it "returns false" do
        expect(subject.has_author_value?).to be false
      end
    end

    context "when a regular user ID is set" do
      before { subject.values = [42] }

      it "returns false" do
        expect(subject.has_author_value?).to be false
      end
    end
  end

  describe "#transformed_value_with_wp" do
    let(:author) { build_stubbed(:user, id: 100) }
    let(:work_package) { build_stubbed(:work_package, author:) }
    let(:logged_in_user) { build_stubbed(:user, id: 200) }

    context "when value is work_package_author" do
      before { subject.values = ["work_package_author"] }

      it "returns the work package author's ID" do
        result = subject.send(:transformed_value_with_wp, "work_package_author", work_package)
        expect(result).to eq(100)
      end

      it "does not depend on the logged-in user" do
        result = subject.send(:transformed_value_with_wp, "work_package_author", work_package)
        expect(result).to eq(author.id)
      end
    end

    context "when value is current_user" do
      before do
        subject.values = ["current_user"]
        login_as logged_in_user
      end

      it "returns the logged-in user's ID" do
        result = subject.send(:transformed_value_with_wp, "current_user", work_package)
        expect(result).to eq(200)
      end
    end

    context "when value is a regular user ID" do
      before { subject.values = [42] }

      it "returns the value as-is" do
        result = subject.send(:transformed_value_with_wp, 42, work_package)
        expect(result).to eq(42)
      end
    end

    context "when work package has no author" do
      let(:work_package) { build_stubbed(:work_package, author: nil) }

      before { subject.values = ["work_package_author"] }

      it "returns nil" do
        result = subject.send(:transformed_value_with_wp, "work_package_author", work_package)
        expect(result).to be_nil
      end
    end
  end

  describe "assigned_to and responsible markers" do
    let(:assignee) { build_stubbed(:user, id: 10) }
    let(:accountable) { build_stubbed(:user, id: 20) }
    let(:work_package) { build_stubbed(:work_package, assigned_to: assignee, responsible: accountable) }

    it "offers both markers in #associated" do
      keys = subject.associated.map(&:first)
      expect(keys).to include("assigned_to", "responsible")
    end

    it "preserves the markers in #values=" do
      subject.values = ["assigned_to", "responsible"]
      expect(subject.values).to eq(["assigned_to", "responsible"])
    end

    it "resolves assigned_to to the work package's original assignee" do
      expect(subject.send(:transformed_value_with_wp, "assigned_to", work_package)).to eq(10)
    end

    it "resolves responsible to the work package's original accountable" do
      expect(subject.send(:transformed_value_with_wp, "responsible", work_package)).to eq(20)
    end
  end

  describe "validation" do
    context "when work_package_author is set" do
      before { subject.values = ["work_package_author"] }

      it "does not add :not_logged_in error" do
        errors = ActiveModel::Errors.new(CustomAction.new)
        subject.validate errors
        expect(errors.symbols_for(:actions)).not_to include :not_logged_in
      end
    end

    context "when current_user is set and user is not logged in" do
      before { subject.values = ["current_user"] }

      it "adds :not_logged_in error" do
        errors = ActiveModel::Errors.new(CustomAction.new)
        subject.validate errors
        expect(errors.symbols_for(:actions)).to include :not_logged_in
      end
    end
  end

  # The "user_attribute_<id>" marker reads the executing user's value of a
  # UserCustomField of format "user" (a user attribute), mirroring the
  # "current_user" marker that reads from User.current.
  describe "user attribute custom field value" do
    shared_let(:attribute_value_user) { create(:user) }
    shared_let(:user_attribute_cf) { create(:user_custom_field, :user) }
    let(:marker) { "user_attribute_#{user_attribute_cf.id}" }
    let(:work_package) { build_stubbed(:work_package) }

    context "when the executing user has a value for the attribute" do
      let(:current_user) do
        create(:user, custom_values: [build(:custom_value,
                                            custom_field: user_attribute_cf,
                                            value: attribute_value_user.id.to_s)])
      end

      before { login_as current_user }

      it "offers the user attribute as a selectable value" do
        expect(subject.associated)
          .to include([marker, I18n.t("custom_actions.actions.assigned_to.user_attribute_value",
                                      name: user_attribute_cf.name)])
      end

      it "preserves the marker as the stored value" do
        subject.values = [marker]
        expect(subject.values).to eq([marker])
      end

      it "resolves the marker to the executing user's attribute value" do
        result = subject.send(:transformed_value_with_wp, marker, work_package)
        expect(result).to eq(attribute_value_user.id)
      end
    end

    context "when the executing user is anonymous" do
      before { login_as User.anonymous }

      it "resolves the marker to nil" do
        result = subject.send(:transformed_value_with_wp, marker, work_package)
        expect(result).to be_nil
      end
    end

    context "when the executing user has no value for the attribute" do
      let(:current_user) { create(:user) }

      before { login_as current_user }

      it "resolves the marker to nil" do
        result = subject.send(:transformed_value_with_wp, marker, work_package)
        expect(result).to be_nil
      end
    end

    context "when the referenced user attribute no longer exists" do
      let(:current_user) { create(:user) }

      before do
        login_as current_user
        user_attribute_cf.destroy
      end

      it "resolves the marker to nil" do
        result = subject.send(:transformed_value_with_wp, marker, work_package)
        expect(result).to be_nil
      end

      it "is rejected by allowed-value validation" do
        errors = ActiveModel::Errors.new(CustomAction.new)
        subject.values = [marker]
        subject.validate errors
        expect(errors.symbols_for(:actions)).to include(:inclusion)
      end
    end
  end
end
