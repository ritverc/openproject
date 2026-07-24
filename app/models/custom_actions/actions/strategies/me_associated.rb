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

# Strategy for user-type actions (assignee, accountable, user custom fields).
#
# Besides selecting a concrete principal, the action value may be one of the
# special, dynamic markers resolved against the work package at apply time:
#   - "current_user"           -> the executing user
#   - "work_package_author"    -> the work package's author
#   - "assigned_to"            -> the work package's assignee
#   - "responsible"            -> the work package's accountable
#   - "user_custom_field_<id>" -> the value of a user-format work package custom field
#   - "user_attribute_<id>"    -> the executing user's value of a user-format user
#                               attribute (a UserCustomField of format "user")
#
# The work-package-dependent markers read the *original* (pre-action) value, so
# the order in which a custom action's actions are applied does not affect the
# result. This makes "save & restore a person on status change" reliable, e.g.
# copy the assignee into a custom field and clear the assignee in the same action.
module CustomActions::Actions::Strategies::MeAssociated
  include ::CustomActions::Actions::Strategies::Associated

  USER_CUSTOM_FIELD_VALUE_PREFIX = "user_custom_field_"
  USER_CUSTOM_FIELD_VALUE_PATTERN = /\A#{Regexp.escape(USER_CUSTOM_FIELD_VALUE_PREFIX)}(\d+)\z/

  # Marker prefix for the executing user's value of a UserCustomField of
  # format "user" (a user attribute). Distinct from
  # +USER_CUSTOM_FIELD_VALUE_PREFIX+ so the two source kinds (WorkPackage
  # custom field vs. user attribute) cannot collide even though they share
  # the underlying +custom_fields+ STI table.
  USER_ATTRIBUTE_VALUE_PREFIX = "user_attribute_"
  USER_ATTRIBUTE_VALUE_PATTERN = /\A#{Regexp.escape(USER_ATTRIBUTE_VALUE_PREFIX)}(\d+)\z/

  CURRENT_USER_VALUE_KEY = "current_user"
  AUTHOR_VALUE_KEY = "work_package_author"
  ASSIGNED_TO_VALUE_KEY = "assigned_to"
  RESPONSIBLE_VALUE_KEY = "responsible"

  def me_value
    [current_user_value_key, current_user_name]
  end

  def author_value
    [author_value_key, author_name]
  end

  def assigned_to_value
    [ASSIGNED_TO_VALUE_KEY, field_value_name(:assigned_to)]
  end

  def responsible_value
    [RESPONSIBLE_VALUE_KEY, field_value_name(:responsible)]
  end

  def author_value_key
    AUTHOR_VALUE_KEY
  end

  def author_name
    I18n.t("custom_actions.actions.assigned_to.author_value")
  end

  ##
  # [key, label] pairs for every user-format work package custom field, letting
  # the action copy that field's value into the target user field.
  def user_custom_field_values
    assignable_user_custom_fields.map do |custom_field|
      [user_custom_field_value_key(custom_field.id), user_custom_field_name(custom_field)]
    end
  end

  def user_custom_field_value_key(custom_field_id)
    "#{USER_CUSTOM_FIELD_VALUE_PREFIX}#{custom_field_id}"
  end

  def user_custom_field_name(custom_field)
    field_value_name(custom_field.name)
  end

  ##
  # [key, label] pairs for every user-format user attribute (a UserCustomField
  # of format "user"), letting the action copy the executing user's value of
  # that attribute into the target user field. The value is read from
  # +User.current+ at apply time, mirroring the +current_user+ marker.
  def user_attribute_values
    assignable_user_attribute_custom_fields.map do |custom_field|
      [user_attribute_value_key(custom_field.id), user_attribute_name(custom_field)]
    end
  end

  def user_attribute_value_key(custom_field_id)
    "#{USER_ATTRIBUTE_VALUE_PREFIX}#{custom_field_id}"
  end

  def user_attribute_name(custom_field)
    I18n.t("custom_actions.actions.assigned_to.user_attribute_value", name: custom_field.name)
  end

  ##
  # The marker for this action's own target field. It is excluded from the
  # offered value sources to avoid a pointless self copy. Overridden per action.
  def self_source_marker
    nil
  end

  ##
  # The full list of selectable values:
  #   1. the executing user (current_user)
  #   2. the work package author
  #   3. the work package assignee / accountable
  #   4. the value of each user custom field
  #   5. all available principals (users and groups)
  # The action's own field is never offered as a source.
  def associated
    dynamic_value_sources + available_principles
  end

  ##
  # Keeps the special string markers as-is, while coercing concrete ids to
  # integers.
  def values=(values)
    @values = Array(values).map do |value|
      special_value_marker?(value) ? value.to_s : to_integer_or_nil(value)
    end.uniq
  end

  ##
  # Resolves a single value (a concrete id or a special marker) against the
  # given work package. Work-package-dependent markers read the *original*
  # (pre-action) value so the order of applied actions does not matter.
  def transformed_value_with_wp(val, work_package)
    case val.to_s
    when current_user_value_key
      resolve_current_user
    when author_value_key
      work_package.author_id_was
    when ASSIGNED_TO_VALUE_KEY
      work_package.assigned_to_id_was
    when RESPONSIBLE_VALUE_KEY
      work_package.responsible_id_was
    else
      wp_cf_id = user_custom_field_value_id(val)
      if wp_cf_id
        resolve_user_custom_field(work_package, wp_cf_id)
      else
        ua_cf_id = user_attribute_value_id(val)
        ua_cf_id ? resolve_user_attribute_custom_field(ua_cf_id) : val
      end
    end
  end

  def current_user_value_key
    CURRENT_USER_VALUE_KEY
  end

  def current_user_name
    I18n.t("custom_actions.actions.assigned_to.executing_user_value")
  end

  def has_me_value?
    values.first == current_user_value_key
  end

  def has_author_value?
    values.first == author_value_key
  end

  def validate(errors)
    super
    validate_me_value(errors)
  end

  private

  ##
  # The dynamic (non-principal) value sources offered by the action, with the
  # action's own field filtered out.
  def dynamic_value_sources
    ([me_value, author_value, assigned_to_value, responsible_value] +
       user_custom_field_values +
       user_attribute_values)
      .reject { |key, _| key == self_source_marker }
  end

  def special_value_marker?(value)
    value = value.to_s
    built_in_value_markers.include?(value) \
      || user_custom_field_value_id(value).present? \
      || user_attribute_value_id(value).present?
  end

  def built_in_value_markers
    [current_user_value_key, author_value_key, ASSIGNED_TO_VALUE_KEY, RESPONSIBLE_VALUE_KEY]
  end

  ##
  # Label for a "use value of <field>" marker. Accepts a work package attribute
  # symbol (resolved to its human name) or a ready-made string (custom field name).
  def field_value_name(name)
    name = WorkPackage.human_attribute_name(name) if name.is_a?(Symbol)
    I18n.t("custom_actions.actions.assigned_to.field_value", name:)
  end

  ##
  # User-format work package custom fields offered as value sources. A user
  # custom field action excludes its own field to avoid a pointless self copy.
  def assignable_user_custom_fields
    fields = WorkPackageCustomField.where(field_format: "user").order(:name)
    fields = fields.where.not(id: custom_field.id) if respond_to?(:custom_field)
    fields
  end

  ##
  # User-format user attributes (UserCustomField of format "user") offered as
  # value sources. Their value is read from the executing user (User.current)
  # at apply time, mirroring the +current_user+ marker. A user attribute can
  # never be the target of a work package custom action (different customizable
  # class), so no self-source exclusion is needed.
  def assignable_user_attribute_custom_fields
    UserCustomField.where(field_format: "user").order(:name)
  end

  ##
  # Extracts the custom field id from a "user_custom_field_<id>" marker, or nil.
  def user_custom_field_value_id(value)
    match = value.to_s.match(USER_CUSTOM_FIELD_VALUE_PATTERN)
    match && match[1].to_i
  end

  ##
  # Extracts the custom field id from a "user_attribute_<id>" marker, or nil.
  def user_attribute_value_id(value)
    match = value.to_s.match(USER_ATTRIBUTE_VALUE_PATTERN)
    match && match[1].to_i
  end

  def resolve_current_user
    User.current.id if User.current.logged?
  end

  ##
  # The work package's *original* value for the given user custom field (the
  # user id), or nil when unset. For multi-value fields the first present value
  # is used.
  def resolve_user_custom_field(work_package, custom_field_id)
    custom_field = WorkPackageCustomField.find_by(id: custom_field_id)
    return unless custom_field

    Array(work_package.custom_value_was_for(custom_field))
      .compact
      .first
      .presence
      &.to_i
  end

  ##
  # The executing user's value for a user-format user attribute (a
  # UserCustomField of format "user"), resolved at apply time so it reflects
  # the current state of the user's attribute. Returns the stored Principal ID
  # (User/Group/PlaceholderUser) or nil when the executing user is not logged
  # in or the attribute is unset. For multi-value attributes the first present
  # value is used, mirroring #resolve_user_custom_field.
  def resolve_user_attribute_custom_field(custom_field_id)
    custom_field = UserCustomField.find_by(id: custom_field_id)
    return unless custom_field
    return unless User.current.logged?

    Array(User.current.custom_value_for(custom_field))
      .map(&:value)
      .compact
      .first
      .presence
      &.to_i
  end

  def validate_me_value(errors)
    if has_me_value? && !User.current.logged?
      errors.add :actions,
                 :not_logged_in,
                 name: human_name
    end
  end
end
