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

class CustomActions::BaseService
  include Shared::BlockService

  attr_accessor :user

  def call(attributes:,
           action:,
           &)
    set_attributes(action, attributes)

    contract = CustomActions::CuContract.new(action)
    result = ServiceResult.new(success: contract.validate && action.save,
                               result: action,
                               errors: contract.errors)

    block_with_result(result, &)
  end

  private

  def set_attributes(action, attributes)
    actions_attributes = attributes.delete(:actions)
    action_options_attributes = attributes.delete(:action_options)
    conditions_attributes = attributes.delete(:conditions)
    action.attributes = attributes

    set_actions(action, actions_attributes.symbolize_keys, action_options_attributes) if actions_attributes
    set_conditions(action, conditions_attributes.symbolize_keys) if conditions_attributes
  end

  # +actions_attributes+ maps action keys to their submitted values.
  # +action_options+ (optional) maps action keys to a hash of admin options,
  # e.g. `{ assigned_to: { set_if_empty: "0" } }`.
  # The option is applied to both newly added and already existing actions.
  def set_actions(action, actions_attributes, action_options = nil)
    action_options = (action_options || {}).symbolize_keys
    existing_action_keys = action.actions.map(&:key)

    remove_actions(action, existing_action_keys - actions_attributes.keys)
    update_actions(action, actions_attributes.slice(*existing_action_keys), action_options)
    add_actions(action, actions_attributes.slice(*(actions_attributes.keys - existing_action_keys)), action_options)
  end

  def remove_actions(action, keys)
    keys.each do |key|
      remove_action(action, key)
    end
  end

  def update_actions(action, key_values, action_options = {})
    key_values.each do |key, values|
      update_action(action, key, values, action_options[key])
    end
  end

  def add_actions(action, key_values, action_options = {})
    key_values.each do |key, values|
      add_action(action, key, values, action_options[key])
    end
  end

  def update_action(action, key, values, options = nil)
    target = action.actions.detect { |a| a.key == key }
    target.values = values
    apply_options(target, options)
  end

  def add_action(action, key, values, options = nil)
    instance = available_action_for(action, key).new(values)
    apply_options(instance, options)
    action.actions << instance
  end

  # Forward the admin-toggled "set if empty" flag onto the action instance.
  #
  # +options+ may be a +Hash+, an +ActionController::Parameters+, or +nil+
  # (the latter happens when the form submitted no checkbox for this action,
  # e.g. it was unchecked). In the +nil+ case the flag is reset to false,
  # which is the documented semantics of an unchecked checkbox.
  #
  # The flag lives on the in-memory action instance and is persisted into
  # the dedicated +action_options+ DB column by +CustomAction#capture_action_options+
  # (a +before_save+ callback), keeping it separate from the +actions+ YAML
  # column that still stores only the values.
  #
  # +options+ supports indifferent-style access via +[]+, so the flag is
  # looked up with both symbol and string keys.
  def apply_options(target, options)
    return target unless target.respond_to?(:set_if_empty=)

    target.set_if_empty = options && (options[:set_if_empty] || options["set_if_empty"])
    target
  end

  def remove_action(action, key)
    action.actions.reject! { |a| a.key == key }
  end

  def set_conditions(action, conditions_attributes)
    action.conditions = conditions_attributes.map do |key, values|
      available_condition_for(action, key).new(values)
    end
  end

  def available_action_for(action, key)
    action.available_actions.detect { |a| a.key == key } || CustomActions::Actions::Inexistent
  end

  def available_condition_for(action, key)
    action.available_conditions.detect { |a| a.key == key } || CustomActions::Conditions::Inexistent
  end
end
