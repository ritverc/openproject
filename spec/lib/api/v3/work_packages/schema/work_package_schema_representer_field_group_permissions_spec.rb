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

RSpec.describe API::V3::WorkPackages::Schema::WorkPackageSchemaRepresenter,
               "field group visibility" do
  shared_let(:project) { create(:project) }
  shared_let(:type) { create(:type) }
  shared_let(:status) { create(:status) }
  shared_let(:author) { create(:user) }

  let(:groups) do
    [Type::AttributeGroup.new(type, "people", %w[assignee responsible]),
     Type::AttributeGroup.new(type, "details", %w[priority])]
  end
  let(:work_package) { build_stubbed(:work_package, project:, type:, status:, author:) }
  let(:current_user) { author }
  let(:schema) { API::V3::WorkPackages::Schema::SpecificWorkPackageSchema.new(work_package:) }
  let(:representer) { described_class.create(schema, self_link: nil, current_user:) }

  before do
    allow(type).to receive(:attribute_groups).and_return(groups)
    # Isolate the visibility filtering from the (heavy) group rendering.
    allow(representer).to receive(:form_config_attribute_representation, &:key)
    login_as(current_user)
  end

  subject { representer.send(:attribute_groups) }

  context "without any configured restriction" do
    it { is_expected.to eq(%w[people details]) }
  end

  context "when the people group is hidden for the author" do
    before do
      create(:field_group_permission,
             type:, status:, field_group: "people", role: "author", visible: false)
    end

    it "excludes the hidden group" do
      expect(subject).to eq(%w[details])
    end
  end
end
