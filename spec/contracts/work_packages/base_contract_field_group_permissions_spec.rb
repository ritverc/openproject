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

RSpec.describe WorkPackages::BaseContract, "field group permissions" do
  shared_let(:project) { create(:project) }
  shared_let(:type) { create(:type) }
  shared_let(:status) { create(:status) }
  shared_let(:author) { create(:user) }
  shared_let(:stranger) { create(:user) }

  let(:work_package) do
    build_stubbed(:work_package, project:, type:, status:, author:)
  end

  subject(:contract) { described_class.new(work_package, current_user) }

  before do
    mock_permissions_for(current_user) do |mock|
      mock.allow_in_project :view_work_packages, :edit_work_packages, project:
    end
  end

  # The default "people" group holds the assignee and responsible attributes.
  def writable = contract.writable_attributes

  context "when the current user is the author and the people group is read-only" do
    let(:current_user) { author }

    before do
      create(:field_group_permission,
             type:, status:, field_group: "people", role: "author",
             visible: true, read_only: true)
    end

    it "removes the group's attributes from the writable set" do
      expect(writable).not_to include("assigned_to")
      expect(writable).not_to include("assigned_to_id")
      expect(writable).not_to include("responsible")
    end
  end

  context "when the current user holds no matching role" do
    let(:current_user) { stranger }

    before do
      create(:field_group_permission,
             type:, status:, field_group: "people", role: "author",
             visible: true, read_only: true)
    end

    it "keeps the attributes writable" do
      expect(writable).to include("assigned_to")
    end
  end

  context "when a read-only group holds the merged date attribute" do
    let(:current_user) { author }

    before do
      allow(type).to receive(:attribute_groups)
        .and_return([Type::AttributeGroup.new(type, "dates", %w[date])])
      create(:field_group_permission,
             type:, status:, field_group: "dates", role: "author",
             visible: true, read_only: true)
    end

    it "removes both the start and due date from the writable set" do
      expect(writable).not_to include("start_date")
      expect(writable).not_to include("due_date")
    end
  end
end
