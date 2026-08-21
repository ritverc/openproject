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

class CustomActions::Actions::Notify < CustomActions::Actions::Base
  include CustomActions::Actions::Strategies::MeAssociated

  # Notify is a multi-valued action. Besides selecting concrete principals
  # (users and groups), the value may be any of the dynamic markers provided
  # by the MeAssociated strategy, mirroring the assigned_to and responsible
  # actions:
  #   - "current_user"            -> the executing user
  #   - "work_package_author"     -> the work package's author
  #   - "assigned_to"             -> the work package's assignee
  #   - "responsible"             -> the work package's accountable
  #   - "user_custom_field_<id>"  -> the value of a user-format work package
  #                                  custom field
  #   - "user_attribute_<id>"     -> the executing user's value of a
  #                                  user-format user attribute
  # At apply time each marker is resolved against the work package and the
  # resulting principals are turned into mention syntax ("user#<id>" /
  # "group#<id>") written into the work package's comment.
  def apply_value(work_package)
    comment = resolved_principals(work_package).map do |principal|
      prefix = principal.is_a?(User) ? "user" : "group"
      "#{prefix}##{principal.id}"
    end.join(", ")

    work_package.journal_notes = comment
  end

  def available_principles
    principals.map { |u| [u.id, u.name] }
  end

  # Render through the user autocompleter branch of the admin form so that
  # the dynamic value sources (author, user custom fields, ...) are offered
  # as additional selectable options, just like assigned_to and responsible.
  def type
    :user
  end

  def multi_value?
    true
  end

  # Notify has no "own" target field, so none of the dynamic value sources
  # needs to be excluded (MeAssociated#self_source_marker returns nil by
  # default, which is exactly what we want here).

  # Overridden because notify is multi-valued: the executing-user marker may
  # appear at any position among the selected values, not only as the first
  # one (which the default MeAssociated#has_me_value? assumes).
  def has_me_value?
    values.include?(current_user_value_key)
  end

  def self.key
    :notify
  end

  private

  # Resolve every selected value (a concrete id or a dynamic marker) against
  # the work package and return the matching principals. Markers that cannot
  # be resolved (e.g. an unset user custom field or an anonymous executing
  # user) yield nil and are skipped.
  def resolved_principals(work_package)
    ids = values.filter_map { |value| transformed_value_with_wp(value, work_package) }
    principals.where(id: ids)
  end

  def principals
    Principal
      .not_locked
      .select(:id, :type)
      .select_for_name
      .ordered_by_name
  end
end
