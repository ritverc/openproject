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

class Queries::Users::Filters::DepartmentFilter < Queries::Users::Filters::UserFilter
  def self.key
    :department
  end

  def type
    :list_optional
  end

  def human_name
    User.human_attribute_name(:department)
  end

  def allowed_values
    @allowed_values ||= ::Group.organizational_units.pluck(:id).map { |g| [g, g.to_s] }
  end

  def available?
    ::Group.organizational_units.exists?
  end

  def where
    case operator
    when "="
      "users.id IN (#{department_subselect})"
    when "!"
      "users.id NOT IN (#{department_subselect})"
    when "*"
      "users.id IN (#{any_department_subselect})"
    when "!*"
      "users.id NOT IN (#{any_department_subselect})"
    end
  end

  def autocomplete_options
    {
      component: "opce-user-autocompleter",
      resource: "principals",
      url: ::API::V3::Utilities::PathHelper::ApiV3Path.principals,
      filters: [{ name: "type", operator: "=", values: %w[Group] }],
      searchKey: "any_name_attribute",
      inputValue: values,
      bindValue: "id"
    }
  end

  private

  def department_subselect
    User.joins(:departments).where(departments_users: { id: values }).select(:id).to_sql
  end

  def any_department_subselect
    User.joins(:departments).select(:id).to_sql
  end
end

