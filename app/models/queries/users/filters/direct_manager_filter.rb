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

class Queries::Users::Filters::DirectManagerFilter < Queries::Users::Filters::UserFilter
  def self.key
    :direct_manager
  end

  def type
    :list_optional
  end

  def human_name
    User.human_attribute_name(:direct_manager)
  end

  def allowed_values
    @allowed_values ||= ::Principal.where.not(type: %w[DeletedUser AnonymousUser SystemUser]).pluck(:id).map { |p| [p, p.to_s] }
  end

  def where
    case operator
    when "="
      "users.direct_manager_id IN (#{values.map(&:to_i).join(',')})"
    when "!"
      "users.direct_manager_id NOT IN (#{values.map(&:to_i).join(',')}) OR users.direct_manager_id IS NULL"
    when "*"
      "users.direct_manager_id IS NOT NULL"
    when "!*"
      "users.direct_manager_id IS NULL"
    end
  end

  def autocomplete_options
    {
      component: "opce-user-autocompleter",
      resource: "principals",
      url: ::API::V3::Utilities::PathHelper::ApiV3Path.principals,
      filters: [{ name: "type", operator: "=", values: %w[User Group PlaceholderUser] },
                { name: "status", operator: "!", values: [Principal.statuses[:locked].to_s] }],
      searchKey: "any_name_attribute",
      inputValue: values,
      bindValue: "id"
    }
  end
end

