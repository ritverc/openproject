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

RSpec.describe FieldGroupPermissions::BulkUpdateService do
  shared_let(:type) { create(:type) }
  shared_let(:status) { create(:status) }

  subject(:service) { described_class.new(type:, field_group: "people") }

  def rule_for(role)
    FieldGroupPermission.find_by(type_id: type.id, status_id: status.id, field_group: "people", role:)
  end

  it "stores only rules that differ from the permissive default" do
    service.call(
      hidden: {},
      read_only: { status.id.to_s => { "author" => "1" } }
    )

    expect(rule_for("author")).to have_attributes(visible: true, read_only: true)
    # assignee/responsible are visible and editable (default) and must not be stored
    expect(rule_for("assignee")).to be_nil
    expect(rule_for("responsible")).to be_nil
  end

  it "stores a hidden rule when the hide box is checked" do
    service.call(
      hidden: { status.id.to_s => { "author" => "1" } },
      read_only: {}
    )

    expect(rule_for("author")).to have_attributes(visible: false, read_only: false)
  end

  it "replaces existing rules of the group and leaves other groups untouched" do
    create(:field_group_permission, type:, status:, field_group: "people", role: "author", visible: false)
    other = create(:field_group_permission, type:, status:, field_group: "details", role: "author", visible: false)

    service.call(hidden: {}, read_only: {})

    expect(FieldGroupPermission.where(type_id: type.id, status_id: status.id, field_group: "people")).to be_empty
    expect(FieldGroupPermission.exists?(other.id)).to be(true)
  end
end
