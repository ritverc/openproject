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

class FieldGroupPermissionsController < ApplicationController
  include OpTurbo::ComponentStream

  before_action :require_admin
  before_action :find_type
  before_action :find_field_group

  # Opens the access matrix as a modal dialog (async-dialog / turbo stream),
  # triggered from the kebab menu of a field group in the type form configuration.
  def edit
    permissions = FieldGroupPermission
                  .where(type_id: @type.id, field_group: @field_group_key)
                  .index_by { |permission| [permission.status_id, permission.role] }

    respond_with_dialog(
      WorkPackageTypes::FormConfiguration::FieldGroupPermissionsDialogComponent.new(
        type: @type,
        field_group: @field_group,
        permissions:
      )
    )
  end

  def update
    FieldGroupPermissions::BulkUpdateService
      .new(type: @type, field_group: @field_group_key)
      .call(hidden: matrix_param(:hidden), read_only: matrix_param(:read_only))

    render_success_flash_message_via_turbo_stream(message: t(:notice_successful_update))
    respond_with_turbo_streams
  end

  private

  def find_type
    @type = ::Type.find(params.expect(:type_id))
  end

  # Only regular attribute groups can be configured (query groups embed queries,
  # not attributes).
  def field_groups
    @field_groups ||= @type.attribute_groups.grep(Type::AttributeGroup)
  end

  def find_field_group
    requested = params[:field_group].presence
    @field_group = field_groups.find { |group| group.key.to_s == requested } || field_groups.first
    @field_group_key = @field_group&.key.to_s
  end

  # The matrix always submits status_id => role => "1", with unchecked boxes
  # simply absent. The service only reads the known status/role combinations and
  # casts the values, so returning the raw (indifferent-access) hash is safe.
  def matrix_param(key)
    value = params[key]
    value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : (value || {})
  end
end
