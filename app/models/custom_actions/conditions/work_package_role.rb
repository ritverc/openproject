# frozen_string_literal: true

class CustomActions::Conditions::WorkPackageRole
  ROLE_OPTIONS = %w[assignee responsible author].freeze
  
  attr_reader :values

  def initialize(values = nil)
    self.values = values
  end

  def values=(vals)
    @values = Array(vals).map(&:to_s).compact_blank.uniq
  end

  def self.key
    :work_package_role
  end

  def key
    self.class.key
  end

  def allowed_values
    ROLE_OPTIONS.map do |value|
      { value:, label: I18n.t("custom_actions.work_package_role_condition.values.#{value}") }
    end
  end

  def value_objects
    values.map do |v|
      allowed_values.find { |opt| opt[:value] == v }
    end.compact
  end

  def human_name
    I18n.t('custom_actions.work_package_role_condition.name')
  end

  def fulfilled_by?(work_package, user)
    return true if values.empty?
    return false if user.nil?

    values.any? do |role|
      case role
      when 'assignee'
        user_is_assigned_principal?(work_package.assigned_to_id, user)
      when 'responsible'
        user_is_assigned_principal?(work_package.responsible_id, user)
      when 'author'
        work_package.author_id == user.id
      else
        false
      end
    end
  end

  # Check if user is the given principal directly or via group membership.
  def user_is_assigned_principal?(principal_id, user)
    return false if principal_id.nil?
    return true if principal_id == user.id
    user.group_ids.include?(principal_id)
  end

  def validate(_errors)
    # All values are hardcoded constants — always valid
  end

  def self.getter(custom_action)
    stored = custom_action.read_attribute(:work_package_role_condition)
    parsed = case stored
             when String
               JSON.parse(stored) rescue []
             when Array
               stored
             else
               []
             end

    new(parsed) if parsed.present?
  end

  def self.setter(custom_action, condition)
    if condition&.values&.any?
      custom_action.update_column(
        :work_package_role_condition,
        condition.values.to_json
      )
    else
      custom_action.update_column(:work_package_role_condition, nil)
    end
  end

  def self.custom_action_scope(_work_packages, _user)
    CustomAction.where.not(work_package_role_condition: [nil, ''])
  end
end
