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

# Adds an +action_options+ text column to +custom_actions+ that persists the
# per-action admin-toggleable flag ("set if empty") introduced by the custom
# actions admin form.
#
# The column stores a serialized Hash keyed by action key:
#
#   { "assigned_to" => { "set_if_empty" => false }, ... }
#
# This keeps the flag in a dedicated, queryable column rather than mixing
# it into the existing YAML-serialized +actions+ column (which still holds
# only the action values, as before).
class AddActionOptionsToCustomActions < ActiveRecord::Migration[8.1]
  def change
    add_column :custom_actions, :action_options, :text
  end
end
