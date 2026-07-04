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

RSpec.describe API::V3::WorkPackages::WorkPackageRepresenter, "restrictedFieldGroups" do
  shared_let(:type) { create(:type) }
  shared_let(:status) { create(:status) }
  shared_let(:project) { create(:project, types: [type]) }
  shared_let(:user) { create(:user) }

  let(:work_package) do
    create(:work_package, project:, type:, status:, author: user)
  end

  let(:representer) { described_class.create(work_package, current_user: user, embed_links: false) }

  subject(:json) { representer.to_json }

  before do
    login_as user
    mock_permissions_for(user) do |mock|
      mock.allow_in_project :view_work_packages, :edit_work_packages, project:
    end
  end

  context "without any configured matrix" do
    it "omits the property" do
      expect(json).not_to have_json_path("restrictedFieldGroups")
    end
  end

  context "with a read-only header meta group for the author" do
    before do
      create(:field_group_permission,
             type:, status:, field_group: FieldGroupPermission::HEADER_GROUP_KEY,
             role: "author", visible: true, read_only: true)
    end

    it "exposes the read-only header attributes" do
      expect(JSON.parse(json).dig("restrictedFieldGroups", "readOnly"))
        .to contain_exactly("subject", "type", "status")
    end
  end

  context "with a hidden people group for the author" do
    before do
      create(:field_group_permission,
             type:, status:, field_group: "people", role: "author", visible: false)
    end

    it "exposes the hidden group members" do
      expect(JSON.parse(json).dig("restrictedFieldGroups", "hidden"))
        .to include("assignee", "responsible")
    end
  end

  context "when the user holds no matching role" do
    let(:work_package) do
      create(:work_package, project:, type:, status:, author: create(:user))
    end

    before do
      create(:field_group_permission,
             type:, status:, field_group: "people", role: "author", visible: false)
    end

    it "omits the property" do
      expect(json).not_to have_json_path("restrictedFieldGroups")
    end
  end
end
