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
require "rack/test"

RSpec.describe "API v3 work package form field group permissions" do
  include Rack::Test::Methods
  include API::V3::Utilities::PathHelper

  shared_let(:type) { create(:type) }
  shared_let(:status) { create(:status) }
  shared_let(:project) { create(:project, types: [type]) }
  shared_let(:author) do
    create(:user, member_with_permissions: { project => %i[view_work_packages edit_work_packages] })
  end
  shared_let(:work_package) do
    User.execute_as(author) { create(:work_package, project:, type:, status:, author:) }
  end

  let(:body) { last_response.body }
  let(:group_names) { JSON.parse(body).dig("_embedded", "schema", "_attributeGroups").pluck("name") }
  let(:people_group_name) do
    work_package.type.attribute_groups.find { |group| group.key.to_s == "people" }.translated_key
  end

  def submit_form
    login_as author
    post api_v3_paths.work_package_form(work_package.id),
         { lockVersion: work_package.lock_version }.to_json,
         "CONTENT_TYPE" => "application/json"
  end

  context "without any configured restriction" do
    before { submit_form }

    it "shows all groups and keeps the fields writable" do
      expect(last_response).to have_http_status(200)
      expect(group_names).to include(people_group_name)
      expect(body).to be_json_eql(true).at_path("_embedded/schema/priority/writable")
    end
  end

  context "when the author's people group is hidden and the details group is read-only" do
    before do
      create(:field_group_permission, type:, status:, field_group: "people", role: "author", visible: false)
      create(:field_group_permission, type:, status:, field_group: "details", role: "author",
                                      visible: true, read_only: true)
      submit_form
    end

    it "hides the people group from the schema" do
      expect(group_names).not_to include(people_group_name)
    end

    it "marks the read-only group's priority as not writable" do
      expect(body).to be_json_eql(false).at_path("_embedded/schema/priority/writable")
    end
  end
end
