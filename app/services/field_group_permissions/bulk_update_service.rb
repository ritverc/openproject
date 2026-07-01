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

module FieldGroupPermissions
  # Persists the whole hide/read-only matrix of one field group of a type.
  #
  # The matrix always renders every status and every role, so the full grid is
  # rebuilt from the database (not from the submitted keys): a missing "hide" or
  # "read-only" checkbox means "unchecked". Only rules differing from the
  # permissive default (+visible: true, read_only: false+) are stored.
  class BulkUpdateService
    def initialize(type:, field_group:)
      @type = type
      @field_group = field_group
    end

    def call(hidden:, read_only:)
      hidden = hidden.to_h
      read_only = read_only.to_h
      rows = build_rows(hidden, read_only)

      FieldGroupPermission.transaction do
        FieldGroupPermission.where(type_id: @type.id, field_group: @field_group).delete_all
        FieldGroupPermission.insert_all(rows) if rows.any?
      end
    end

    private

    def build_rows(hidden, read_only)
      now = Time.current

      Status.pluck(:id).flat_map do |status_id|
        FieldGroupPermission::ROLES.filter_map do |role|
          is_hidden = truthy?(hidden.dig(status_id.to_s, role))
          is_read_only = truthy?(read_only.dig(status_id.to_s, role))

          # Skip the permissive default so the table only stores real restrictions.
          next unless is_hidden || is_read_only

          { type_id: @type.id,
            status_id:,
            field_group: @field_group,
            role:,
            visible: !is_hidden,
            read_only: is_read_only,
            created_at: now,
            updated_at: now }
        end
      end
    end

    def truthy?(value)
      ActiveModel::Type::Boolean.new.cast(value) == true
    end
  end
end
