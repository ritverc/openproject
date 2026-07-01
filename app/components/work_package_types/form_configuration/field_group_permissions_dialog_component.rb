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

module WorkPackageTypes
  module FormConfiguration
    # Modal (Primer dialog) that lets an admin configure, for a single attribute
    # group of a work package type, the hide/read-only matrix across statuses
    # (rows) and work package roles (columns): author, assignee, responsible.
    class FieldGroupPermissionsDialogComponent < ApplicationComponent
      include OpTurbo::Streamable
      include OpPrimer::ComponentHelpers

      DIALOG_ID = "field-group-permissions-dialog"

      # @param type [Type] the work package type being configured
      # @param field_group [Type::AttributeGroup] the attribute group
      # @param permissions [Hash{[Integer, String] => FieldGroupPermission}]
      #   existing rules keyed by [status_id, role]
      def initialize(type:, field_group:, permissions:)
        super
        @type = type
        @field_group = field_group
        @permissions = permissions
      end

      private

      def dialog_id = DIALOG_ID

      def dialog_title
        I18n.t("field_group_permissions.dialog_title", name: @field_group.translated_key)
      end

      def field_group_key = @field_group.key.to_s

      def update_path = field_group_permission_path(@type)

      def statuses = @statuses ||= Status.order(:position)

      # [key, label] pairs of the work package roles shown as columns.
      def roles
        { "author" => WorkPackage.human_attribute_name(:author),
          "assignee" => WorkPackage.human_attribute_name(:assigned_to),
          "responsible" => WorkPackage.human_attribute_name(:responsible) }
      end

      def hidden?(status, role)
        (permission = @permissions[[status.id, role]]) && !permission.visible?
      end

      def read_only?(status, role)
        (permission = @permissions[[status.id, role]]) && permission.read_only?
      end
    end
  end
end
