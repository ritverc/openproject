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

RSpec.describe CustomActions::Actions::Responsible do
  let(:key) { :responsible }
  let(:type) { :user }
  let(:allowed_values) do
    principals = [build_stubbed(:user),
                  build_stubbed(:group)]

    allow(Principal)
      .to receive_message_chain(:not_locked, :select, :select_for_name, :ordered_by_name)
            .and_return(principals)

    [{ value: nil, label: "-" },
     { value: "current_user", label: "(Assign to executing user)" },
     { value: "work_package_author", label: "(Assign to work package author)" },
     { value: "assigned_to",
       label: I18n.t("custom_actions.actions.assigned_to.field_value",
                     name: WorkPackage.human_attribute_name(:assigned_to)) },
     { value: principals.first.id, label: principals.first.name },
     { value: principals.last.id, label: principals.last.name }]
  end

  it_behaves_like "base custom action"
  it_behaves_like "associated custom action" do
    describe "#allowed_values" do
      it "is the list of all users and groups" do
        allowed_values

        expect(instance.allowed_values)
          .to eql(allowed_values)
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
        .to include([subject.current_user_value_key, I18n.t("custom_actions.actions.assigned_to.executing_user_value")])
    end

    context "when logged in" do
      before do
        login_as user
      end

      it "returns nil for the current user id" do
        subject.apply work_package
        expect(work_package.responsible_id).to eq(user.id)
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
        expect(work_package.responsible_id).to be_nil
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
      it "assigns the work package author as the responsible" do
        subject.apply work_package
        expect(work_package.responsible_id).to eq(author.id)
      end
    end

    context "when the work package has no author" do
      let(:work_package) { build_stubbed(:work_package, author: nil) }

      it "assigns nil when the work package has no author" do
        subject.apply work_package
        expect(work_package.responsible_id).to be_nil
      end
    end

    context "when a different user is logged in" do
      before do
        login_as other_user
      end

      it "still assigns the work package author, not the logged-in user" do
        subject.apply work_package
        expect(work_package.responsible_id).to eq(author.id)
      end
    end

    context "when validating" do
      it "does not add validation errors for author value" do
        errors = ActiveModel::Errors.new(CustomAction.new)
        subject.validate errors
        expect(errors.symbols_for(:actions)).to be_empty
      end
    end
  end

  describe "assignee field value (save/restore source)" do
    let(:assignee) { build_stubbed(:user) }
    let(:work_package) { build_stubbed(:work_package, assigned_to: assignee) }

    subject { described_class.new(["assigned_to"]) }

    it "offers the assignee field as a source but not the accountable itself" do
      keys = subject.associated.map(&:first)
      expect(keys).to include("assigned_to")
      expect(keys).not_to include("responsible")
    end

    it "assigns the work package's assignee as the accountable" do
      subject.apply(work_package)
      expect(work_package.responsible_id).to eq(assignee.id)
    end
  end
end
