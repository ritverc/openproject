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
    # Renders the virtual "header" meta group (subject, type, status) in the type
    # form configuration. These header fields do not belong to any regular,
    # reorderable attribute group, so the only offered action is opening the field
    # group access matrix for them.
    class HeaderMetaGroupComponent < ApplicationComponent
      include OpPrimer::ComponentHelpers

      def initialize(type:)
        super
        @type = type
      end

      private

      def group_name
        FieldGroupPermission.header_meta_group.translated_key
      end

      def field_group_permissions_path
        edit_field_group_permission_path(@type, field_group: FieldGroupPermission::HEADER_GROUP_KEY)
      end
    end
  end
end
