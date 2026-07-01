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

RSpec.describe "Field group permissions administration",
               :skip_csrf,
               type: :rails_request do
  shared_let(:admin) { create(:admin) }
  shared_let(:type) { create(:type) }
  shared_let(:status) { create(:status) }

  let(:field_group) do
    type.attribute_groups.find { |group| group.is_a?(Type::AttributeGroup) }.key.to_s
  end

  before { login_as admin }

  describe "GET /field_group_permissions/:type_id/edit" do
    it "renders the access matrix dialog for the field group" do
      get edit_field_group_permission_path(type, field_group:),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("field-group-permissions-dialog")
      expect(response.body).to include(status.name)
    end

    it "requires admin" do
      login_as create(:user)

      get edit_field_group_permission_path(type, field_group:)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /field_group_permissions/:type_id" do
    it "persists only rules that differ from the permissive default" do
      patch field_group_permission_path(type),
            headers: { "Accept" => "text/vnd.turbo-stream.html" },
            params: {
              field_group:,
              hidden: {},
              read_only: { status.id.to_s => { "author" => "1" } }
            }

      expect(response).to have_http_status(:ok)

      author_rule = FieldGroupPermission.find_by(type_id: type.id, status_id: status.id,
                                                 field_group:, role: "author")
      expect(author_rule).to have_attributes(visible: true, read_only: true)

      # visible + not read-only is the default and must not be stored
      expect(FieldGroupPermission.exists?(type_id: type.id, status_id: status.id,
                                          field_group:, role: "assignee")).to be(false)
    end

    it "persists a hidden rule when the hide box is checked" do
      patch field_group_permission_path(type),
            headers: { "Accept" => "text/vnd.turbo-stream.html" },
            params: {
              field_group:,
              hidden: { status.id.to_s => { "author" => "1" } },
              read_only: {}
            }

      expect(response).to have_http_status(:ok)

      author_rule = FieldGroupPermission.find_by(type_id: type.id, status_id: status.id,
                                                 field_group:, role: "author")
      expect(author_rule).to have_attributes(visible: false, read_only: false)
    end
  end
end
