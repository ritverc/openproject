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

# Base class for the "invite as viewer / editor / commentor" custom actions.
#
# Each subclass shares the work package with the selected principals (users and
# groups) under a specific builtin WorkPackageRole, using the regular "share
# work package" machinery (Shares::CreateOrUpdateService).
#
# The share is created through the EmptyContract, so the action runs regardless
# of the executing user's +:share_work_packages+ permission and of the work
# package sharing enterprise feature being enabled.
#
# Besides selecting concrete principals, the action value may be any of the
# dynamic, work-package-dependent markers provided by the MeAssociated strategy
# (executing user, work package author, assignee, accountable, the value of any
# user-format custom field) - mirroring the assignee / accountable / user custom
# field actions (see commit b0dc8f53).
class CustomActions::Actions::Invite < CustomActions::Actions::Base
  include CustomActions::Actions::Strategies::MeAssociated

  def self.key
    raise SubclassResponsibilityError
  end

  ##
  # The builtin Role identifier (e.g. Role::BUILTIN_WORK_PACKAGE_VIEWER) the
  # action grants to every resolved principal. Overridden per subclass.
  def self.share_role_builtin
    raise SubclassResponsibilityError
  end

  def type
    :user
  end

  def multi_value?
    true
  end

  # An invite action does not target a work package attribute of its own, so no
  # dynamic value source is filtered out: all of them (executing user, author,
  # assignee, accountable, user custom fields) are offered.
  def self_source_marker
    nil
  end

  def available_principles
    Principal
      .not_locked
      .select(:id, :type)
      .select_for_name
      .ordered_by_name
      .map { |u| [u.id, u.name] }
  end

  def human_name
    I18n.t("custom_actions.actions.#{key}.label")
  end

  ##
  # MeAssociated#has_me_value? only looks at +values.first+, which is incorrect
  # for a multi-value action. Use +include?+ so the "executing user" marker is
  # validated regardless of its position in the selected values.
  def has_me_value?
    values.include?(current_user_value_key)
  end

  ##
  # Shares the work package with every resolved principal under the action's
  # builtin role. Concrete principal ids as well as the dynamic markers are
  # resolved against the work package's original (pre-action) state through
  # MeAssociated#transformed_value_with_wp.
  #
  # Sharing uses Shares::CreateOrUpdateService with the EmptyContract, which:
  #   - creates a new share when the principal has none yet, or
  #   - updates the existing share to the action's role otherwise,
  # and skips the regular :share_work_packages permission check entirely, so the
  # action executes regardless of the current user's rights.
  def apply_value(work_package)
    role = WorkPackageRole.find_by(builtin: self.class.share_role_builtin)
    return unless role

    principal_ids = values
                      .filter_map { |value| transformed_value_with_wp(value, work_package) }
                      .map(&:to_i)
                      .uniq

    principal_ids.each do |principal_id|
      next if principal_id.zero?

      Shares::CreateOrUpdateService
        .new(user: User.current,
             create_contract_class: EmptyContract,
             update_contract_class: EmptyContract)
        .call(entity: work_package,
              user_id: principal_id,
              role_ids: [role.id])
    end
  end
end
