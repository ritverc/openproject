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

RSpec.describe FieldGroupPermission do
  shared_let(:type) { create(:type) }
  shared_let(:status) { create(:status) }
  shared_let(:author) { create(:user) }
  shared_let(:assignee) { create(:user) }
  shared_let(:responsible) { create(:user) }
  shared_let(:stranger) { create(:user) }

  let(:work_package) do
    build_stubbed(:work_package,
                  type:,
                  status:,
                  author:,
                  assigned_to: assignee,
                  responsible:)
  end

  describe "validations" do
    it "requires a field group, role and is unique per type/status/role" do
      create(:field_group_permission, type:, status:, field_group: "people", role: "author")

      duplicate = build(:field_group_permission, type:, status:, field_group: "people", role: "author")
      expect(duplicate).not_to be_valid

      other_role = build(:field_group_permission, type:, status:, field_group: "people", role: "assignee")
      expect(other_role).to be_valid
    end
  end

  describe ".matched_roles" do
    it "returns the roles the user holds for the work package" do
      expect(described_class.matched_roles(work_package, author)).to eq(%w[author])
      expect(described_class.matched_roles(work_package, assignee)).to eq(%w[assignee])
      expect(described_class.matched_roles(work_package, responsible)).to eq(%w[responsible])
      expect(described_class.matched_roles(work_package, stranger)).to eq([])
    end

    it "detects group membership for assignee and responsible" do
      group = create(:group, members: [stranger])
      wp = build_stubbed(:work_package, type:, status:, assigned_to: group)

      expect(described_class.matched_roles(wp, stranger)).to eq(%w[assignee])
    end
  end

  describe ".effective_for" do
    it "returns an empty hash when the user holds no role" do
      create(:field_group_permission, type:, status:, field_group: "people", role: "author", visible: false)

      expect(described_class.effective_for(work_package, stranger)).to eq({})
    end

    it "returns the default (nothing) when no record exists for the held role" do
      expect(described_class.effective_for(work_package, author)).to eq({})
    end

    it "hides a group when the held role has an invisible record" do
      create(:field_group_permission, type:, status:, field_group: "people", role: "author", visible: false)

      expect(described_class.effective_for(work_package, author))
        .to eq("people" => { visible: false, read_only: true })
      expect(described_class.hidden_group_keys(work_package, author)).to eq(%w[people])
      expect(described_class.read_only_group_keys(work_package, author)).to eq([])
    end

    it "marks a visible group read-only" do
      create(:field_group_permission, type:, status:, field_group: "details", role: "author",
                                      visible: true, read_only: true)

      expect(described_class.effective_for(work_package, author))
        .to eq("details" => { visible: true, read_only: true })
      expect(described_class.read_only_group_keys(work_package, author)).to eq(%w[details])
    end

    context "when the user holds several roles" do
      let(:work_package) do
        build_stubbed(:work_package, type:, status:, author:, assigned_to: author, responsible: author)
      end

      it "applies the most permissive rule across the held roles" do
        # author hides the group, assignee keeps it visible -> visible wins
        create(:field_group_permission, type:, status:, field_group: "people", role: "author", visible: false)
        create(:field_group_permission, type:, status:, field_group: "people", role: "assignee",
                                        visible: true, read_only: true)

        # responsible has no record -> unrestricted -> fully permissive
        expect(described_class.effective_for(work_package, author))
          .to eq("people" => { visible: true, read_only: false })
      end

      it "is read-only only when every held role that has a record agrees and none is unrestricted" do
        wp = build_stubbed(:work_package, type:, status:, author:, assigned_to: author)
        create(:field_group_permission, type:, status:, field_group: "people", role: "author",
                                        visible: true, read_only: true)
        create(:field_group_permission, type:, status:, field_group: "people", role: "assignee",
                                        visible: true, read_only: true)

        expect(described_class.effective_for(wp, author))
          .to eq("people" => { visible: true, read_only: true })
      end
    end
  end

  describe ".non_writable_group_keys" do
    it "returns both hidden and read-only groups" do
      create(:field_group_permission, type:, status:, field_group: "people", role: "author", visible: false)
      create(:field_group_permission, type:, status:, field_group: "details", role: "author",
                                      visible: true, read_only: true)

      expect(described_class.non_writable_group_keys(work_package, author))
        .to contain_exactly("people", "details")
    end
  end

  describe "header meta group" do
    it "exposes the reserved key and its synthetic members" do
      expect(described_class::HEADER_GROUP_KEY).to eq("header")
      expect(described_class::HEADER_GROUP_MEMBERS).to eq(%w[subject type status])
    end

    it "provides a stand-in group object for the admin matrix dialog" do
      meta = described_class.header_meta_group

      expect(meta.key).to eq("header")
      expect(meta.translated_key).to be_present
    end
  end

  describe ".expand_members" do
    it "expands the header meta group to its synthetic members" do
      expect(described_class.expand_members(work_package, %w[header]))
        .to contain_exactly("subject", "type", "status")
    end

    it "returns an empty array for no keys" do
      expect(described_class.expand_members(work_package, [])).to eq([])
    end
  end

  describe ".hidden_attribute_keys / .read_only_attribute_keys" do
    it "expands hidden header members" do
      create(:field_group_permission, type:, status:, field_group: "header", role: "author", visible: false)

      expect(described_class.hidden_attribute_keys(work_package, author))
        .to contain_exactly("subject", "type", "status")
      expect(described_class.read_only_attribute_keys(work_package, author)).to eq([])
    end

    it "expands read-only header members" do
      create(:field_group_permission, type:, status:, field_group: "header", role: "author",
                                      visible: true, read_only: true)

      expect(described_class.read_only_attribute_keys(work_package, author))
        .to contain_exactly("subject", "type", "status")
      expect(described_class.hidden_attribute_keys(work_package, author)).to eq([])
    end
  end
end
