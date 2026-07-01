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

RSpec.describe WorkPackageTypes::FormConfiguration::FieldGroupPermissionsDialogComponent, type: :component do
  shared_let(:status) { create(:status) }
  shared_let(:type) { create(:type) }

  let(:field_group) { type.attribute_groups.grep(Type::AttributeGroup).first }

  def render_dialog(permissions = {})
    render_inline(described_class.new(type:, field_group:, permissions:))
  end

  it "renders an unchecked hide and read-only checkbox for each status and role" do
    render_dialog

    FieldGroupPermission::ROLES.each do |role|
      expect(page).to have_unchecked_field("hidden_#{status.id}_#{role}")
      expect(page).to have_unchecked_field("read_only_#{status.id}_#{role}")
    end
  end

  it "reflects an existing hidden and read-only rule as checked boxes" do
    permission = build_stubbed(:field_group_permission,
                               status:, role: "author", visible: false, read_only: true)

    render_dialog({ [status.id, "author"] => permission })

    expect(page).to have_checked_field("hidden_#{status.id}_author")
    expect(page).to have_checked_field("read_only_#{status.id}_author")
  end
end
