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
require_relative "format_field_expectations"

RSpec.describe "users user custom fields", :js do
  let(:user) { create(:admin) }
  let(:section) { create(:user_custom_field_section, name: "Test section") }
  let(:cf_page) { Pages::Admin::Settings::UserCustomFields::Index.new }

  current_user { user }

  before { section }

  it "creates a multi-value user attribute and renders it on the user admin form" do
    cf_page.visit!
    cf_page.click_to_create_new_custom_field "User"

    fill_in "custom_field_name", with: "Mentors"
    select section.name, from: "custom_field_custom_field_section_id"
    check "multi_value"

    click_on "Save"

    expect(page).to have_text("Successful creation")
    expect(page).to have_field("multi_value", checked: true)

    created = UserCustomField.find_by(name: "Mentors")
    expect(created).to be_multi_value
    expect(created.field_format).to eq("user")

    # The freshly-created "user" attribute should render an autocompleter
    # widget on the admin user edit form, just like any other user-typed
    # field does on the work package form.
    target = create(:user)
    visit edit_user_path(target)
    wait_for_network_idle

    within "fieldset", text: section.name do
      expect(page).to have_css("opce-user-autocompleter")
    end
  end

  it "excludes placeholder users from the autocompleter type filter on the user form" do
    create(:user_custom_field,
           name: "Mentors",
           field_format: "user",
           multi_value: true,
           user_custom_field_section: section)

    target = create(:user)
    visit edit_user_path(target)
    wait_for_network_idle

    within "fieldset", text: section.name do
      autocompleter = find("opce-user-autocompleter")
      filters = JSON.parse(autocompleter["data-filters"]).map { |f| f["values"] }
      expect(filters).to include(%w[User Group])
      expect(filters.flatten).not_to include("PlaceholderUser")
    end
  end

  it_behaves_like "expected fields for the User custom field's format", "User"
end
