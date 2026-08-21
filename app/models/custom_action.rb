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

class CustomAction < ApplicationRecord
  validates :name, length: { maximum: 255, minimum: 1 }
  serialize :actions, coder: CustomActions::Actions::Serializer
  # +action_options+ is a dedicated DB column (see the
  # +AddActionOptionsToCustomActions+ migration and +Tables::CustomActions+)
  # storing the per-action admin-toggleable flag ("set if empty") as a JSON
  # Hash keyed by action key:
  #
  #   { "assigned_to" => { "set_if_empty" => false } }
  #
  # The +actions+ YAML column above only stores the action values, as before;
  # the flag lives separately here so it can be queried and indexed.
  serialize :action_options, coder: JSON
  has_and_belongs_to_many :status_conditions, class_name: "Status"
  has_and_belongs_to_many :role_conditions, class_name: "Role"
  has_and_belongs_to_many :type_conditions, class_name: "Type"
  has_and_belongs_to_many :project_conditions, class_name: "Project"

  after_save :persist_conditions
  # Persist the per-action "set if empty" flag from the in-memory action
  # objects back into the +action_options+ DB column right before the record
  # is saved. The +actions+ column itself keeps storing only the values
  # (via CustomActions::Actions::Serializer).
  before_save :capture_action_options
  # Apply the per-action flag out of the +action_options+ DB column onto the
  # in-memory action objects ONCE, right after the record is loaded from the
  # database. This is deliberately done in +after_find+ (and NOT in an
  # +actions+ getter override) so that subsequent mutations of the in-memory
  # action objects by +CustomActions::BaseService#apply_options+ are preserved
  # - both for contract validation (which reads +model.actions+) and for the
  # +before_save :capture_action_options+ callback. Overriding the getter
  # instead would re-apply the STALE DB flag on every read and silently wipe
  # the admin's freshly-set checkbox state (which was the root cause of
  # "changes to existing actions are not saved").
  after_find :apply_action_options_from_db

  attribute :conditions
  define_attribute_method "conditions"

  acts_as_list

  def initialize(*args)
    ret = super

    if actions.nil?
      self.actions = []
    end

    ret
  end

  def reload(*args)
    @conditions = nil

    super
  end

  def actions=(values)
    actions_will_change!
    super
  end

  def self.order_by_name
    order(:name)
  end

  def self.order_by_position
    order(:position)
  end

  def all_actions
    all_of(available_actions, actions)
  end

  def available_actions
    ::CustomActions::Register.actions.map(&:all).flatten
  end

  def all_conditions
    all_of(available_conditions, conditions)
  end

  def available_conditions
    self.class.available_conditions
  end

  def conditions
    @conditions ||= available_conditions.filter_map do |condition_class|
      condition_class.getter(self)
    end
  end

  def conditions=(new_conditions)
    conditions_will_change!
    @conditions = new_conditions
  end

  def conditions_fulfilled?(work_package, user)
    conditions.all? { |c| c.fulfilled_by?(work_package, user) }
  end

  def self.available_conditions
    ::CustomActions::Register.conditions
  end

  private

  def all_of(availables, actual)
    availables.map do |available|
      existing = actual.detect { |a| a.key == available.key }

      existing || available.new
    end
  end

  def persist_conditions
    available_conditions.map do |condition_class|
      condition = conditions.detect { |c| c.instance_of?(condition_class) }

      condition_class.setter(self, condition)
    end
  end

  # Loads the per-action flags out of the +action_options+ DB column and
  # applies them onto the in-memory action objects once, right after the
  # record is fetched from the database. See the +after_find+ callback above
  # for why this lives here and not in an +actions+ getter override.
  def apply_action_options_from_db
    merge_action_options!(actions)
  end

  # Reads the per-action flags out of the +action_options+ DB column and
  # applies them onto the in-memory action objects. Indifferent access is used
  # (symbol and string keys) because JSON serialization produces string keys
  # while the action registry uses symbols.
  def merge_action_options!(actions)
    return actions unless action_options.is_a?(Hash) && action_options.any?

    actions.each do |action|
      opts = action_options[action.key.to_s] || action_options[action.key.to_sym]
      next unless opts.is_a?(Hash)

      action.set_if_empty = opts[:set_if_empty] || opts["set_if_empty"]
    end
    actions
  end

  # Captures the per-action flags from the in-memory action objects into the
  # +action_options+ DB column right before save, so the admin's
  # "set if empty" checkbox state is persisted to the database.
  def capture_action_options
    self.action_options = actions.each_with_object({}) do |action, memo|
      memo[action.key.to_s] = {
        "set_if_empty" => !!action.set_if_empty
      }
    end
  end
end
