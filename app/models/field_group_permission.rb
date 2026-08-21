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

# Access rule for a single attribute group of a work package type.
#
# For a given work package type, field group and status it describes whether the
# group is +visible+ and whether it is +read_only+ for one of the work package
# roles the current user may hold (author / assignee / responsible).
#
# A missing record is equivalent to the least restrictive default
# (+visible: true, read_only: false+), so the feature is fully backwards
# compatible: without any configured record nothing changes.
class FieldGroupPermission < ApplicationRecord
  # The work package roles a user can hold relative to a concrete work package.
  # These are attributes of the work package itself, not project membership roles.
  ROLES = %w[author assignee responsible].freeze

  # Reserved key of the virtual "header" meta group. The work package header
  # fields (subject, type, status) do not belong to any regular attribute group,
  # but can still be hidden / made read-only through the access matrix by
  # configuring this meta group.
  HEADER_GROUP_KEY = "header"
  HEADER_GROUP_MEMBERS = %w[subject type description].freeze

  belongs_to :type, class_name: "::Type"
  belongs_to :status

  enum :role, ROLES.index_by(&:itself)

  validates :field_group, presence: true
  validates :role, presence: true
  validates :field_group,
            uniqueness: { scope: %i[type_id status_id role] }

  # Returns the subset of ROLES the +user+ holds for the given +work_package+.
  def self.matched_roles(work_package, user)
    return [] if user.nil? || user.anonymous?

    roles = []
    roles << "author" if work_package.author_id == user.id
    roles << "assignee" if principal_matches?(work_package.assigned_to, user)
    roles << "responsible" if principal_matches?(work_package.responsible, user)
    roles
  end

  # Whether the +principal+ (User or Group) resolves to the given +user+.
  def self.principal_matches?(principal, user)
    return false if principal.nil?
    return true if principal.id == user.id

    principal.is_a?(Group) && principal.user_ids.include?(user.id)
  end

  # Effective restrictions for the given work package and user, combining all
  # roles the user holds with the least restrictive ("most permissive") rule
  # winning. Only groups that end up restricted are returned.
  #
  # @return [Hash{String => {visible: Boolean, read_only: Boolean}}]
  def self.effective_for(work_package, user)
    roles = matched_roles(work_package, user)
    return {} if roles.empty? || work_package.status_id.nil?

    where(type_id: work_package.type_id, status_id: work_package.status_id, role: roles)
      .group_by(&:field_group)
      .transform_values { |records| combine_rules(roles, records) }
  end

  # Combines the records of a single field group into one effective rule using
  # the least restrictive ("most permissive") outcome across the held roles.
  def self.combine_rules(roles, records)
    # A held role without an explicit record grants full access, so any such
    # role makes the group unrestricted.
    some_role_unrestricted = (roles - records.map(&:role)).any?

    visible = some_role_unrestricted || records.any?(&:visible?)
    editable = some_role_unrestricted || records.any? { |record| record.visible? && !record.read_only? }

    { visible:, read_only: !editable }
  end
  private_class_method :combine_rules

  # Field group keys that must be hidden for the given work package and user.
  def self.hidden_group_keys(work_package, user)
    effective_for(work_package, user).filter_map { |key, rule| key unless rule[:visible] }
  end

  # Field group keys that are visible but read-only for the given work package
  # and user.
  def self.read_only_group_keys(work_package, user)
    effective_for(work_package, user).filter_map { |key, rule| key if rule[:visible] && rule[:read_only] }
  end

  # Field group keys whose attributes must not be writable for the given work
  # package and user, i.e. groups that are hidden or read-only.
  def self.non_writable_group_keys(work_package, user)
    effective_for(work_package, user).filter_map { |key, rule| key if !rule[:visible] || rule[:read_only] }
  end

  # Attribute (form configuration) keys that must be hidden for the given work
  # package and user, expanded from the hidden field groups (incl. the header
  # meta group). Matches the schema property names used on the frontend.
  def self.hidden_attribute_keys(work_package, user)
    expand_members(work_package, hidden_group_keys(work_package, user))
  end

  # Attribute (form configuration) keys that are visible but read-only for the
  # given work package and user, expanded from the read-only field groups (incl.
  # the header meta group).
  def self.read_only_attribute_keys(work_package, user)
    expand_members(work_package, read_only_group_keys(work_package, user))
  end

  # Expands field group keys into their member attribute keys. The +header+ meta
  # group resolves to its synthetic members, every other key to the active
  # members of the matching attribute group of the work package's type.
  def self.expand_members(work_package, group_keys)
    keys = Array(group_keys).map(&:to_s)
    return [] if keys.empty?

    members = keys.delete(HEADER_GROUP_KEY) ? HEADER_GROUP_MEMBERS.dup : []
    members.concat(attribute_group_members(work_package, keys))
    members.uniq
  end

  # Active members of the work package type's attribute groups matching +keys+.
  def self.attribute_group_members(work_package, keys)
    return [] if keys.empty?

    work_package.type.attribute_groups
                .select { |group| group.is_a?(Type::AttributeGroup) && keys.include?(group.key.to_s) }
                .flat_map { |group| group.active_members(work_package.project) }
  end
  private_class_method :attribute_group_members

  # Lightweight stand-in for the +header+ meta group so the admin matrix dialog,
  # which expects an object responding to +key+ and +translated_key+, can render
  # it like a regular attribute group.
  HeaderMetaGroup = Struct.new(:key) do
    def translated_key
      I18n.t("field_group_permissions.header_meta_group")
    end
  end

  def self.header_meta_group
    HeaderMetaGroup.new(HEADER_GROUP_KEY)
  end
end
