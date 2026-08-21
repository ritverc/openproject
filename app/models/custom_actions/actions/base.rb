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

class CustomActions::Actions::Base
  attr_reader :values, :set_if_empty

  DEFAULT_PRIORITY = 100

  # +set_if_empty+ (admin checkbox "set if empty" / "заполнить если пусто"):
  # when true, the action's value is only applied to a work package if the
  # work package does not already have a value for the targeted attribute
  # (see +#apply+ / +#work_package_value_present?+).
  #
  # Options are accepted via a trailing +options+ Hash (rather than keyword
  # arguments) so that historical callers which pass an arbitrary Hash -
  # such as +AssignedTo.new(value: nil)+ in the specs - keep working: Ruby
  # routes such keywords into the trailing Hash positional when the method
  # does not declare explicit keyword parameters.
  def initialize(values = [], options = {})
    self.values = values
    self.set_if_empty = options[:set_if_empty]
  end

  def values=(values)
    @values = Array(values)
  end

  def set_if_empty=(value)
    @set_if_empty = ActiveModel::Type::Boolean.new.cast(value)
  end

  def set_if_empty?
    !!set_if_empty
  end

  def allowed_values
    raise SubclassResponsibilityError
  end

  def value_objects
    values.filter_map do |value|
      allowed_values.find { |v| v[:value] == value }
    end
  end

  def type
    raise SubclassResponsibilityError
  end

  # Public entry point invoked by +UpdateWorkPackageService+.
  #
  # Honors the "set if empty" admin option: when +set_if_empty?+ is true, the
  # action's value is applied only if the work package does not already have a
  # value for the targeted attribute. Subclasses implement the actual mutation
  # in +#apply_value+ (renamed from the previous +#apply+ override point).
  def apply(work_package)
    return if set_if_empty? && work_package_value_present?(work_package)

    apply_value(work_package)
  end

  # Subclasses implement the actual work package mutation here.
  def apply_value(_work_package)
    raise SubclassResponsibilityError
  end

  # Returns true if the work package already has a value for the attribute
  # this action targets. Used by +#apply+ to honor the "set if empty" option.
  #
  # The default implementation prefers the +<key>_id+ foreign-key reader (so
  # associated attributes do not trigger an extra DB query to load the related
  # object) and falls back to the +<key>+ reader. Strategies whose target
  # attribute is not named after +key+ (e.g. custom fields, whose getter is
  # +custom_field_<id>+) still work because they expose a +<key>+ reader.
  def work_package_value_present?(work_package)
    id_reader = :"#{key}_id"
    if work_package.respond_to?(id_reader)
      return value_present?(work_package.send(id_reader))
    end

    reader = key
    if work_package.respond_to?(reader)
      return value_present?(work_package.send(reader))
    end

    # Unknown attribute - be conservative and treat it as empty so the action
    # still applies (preserving the previous, unconditional behavior).
    false
  end

  def human_name
    WorkPackage.human_attribute_name(self.class.key)
  end

  def self.key
    raise SubclassResponsibilityError
  end

  def self.all
    [self]
  end

  def self.for(key)
    if key == self.key
      self
    end
  end

  delegate :key, to: :class

  def required?
    false
  end

  def multi_value?
    false
  end

  def validate(errors)
    validate_value_required(errors)
    validate_only_one_value(errors)
  end

  def priority
    DEFAULT_PRIORITY
  end

  private

  def deconstruct_keys(*)
    { type:, custom_field_based: respond_to?(:custom_field) }
  end

  def validate_value_required(errors)
    if required? && values.empty?
      errors.add :actions,
                 :empty,
                 name: human_name
    end
  end

  def validate_only_one_value(errors)
    if !multi_value? && values.length > 1
      errors.add :actions,
                 :only_one_allowed,
                 name: human_name
    end
  end

  # Whether a raw attribute value read off a work package should be considered
  # "already filled in" for the purposes of the "set if empty" option.
  def value_present?(value)
    case value
    when nil then false
    when String then value.strip.present?
    when Array then value.any? { |v| value_present?(v) }
    else true
    end
  end
end
