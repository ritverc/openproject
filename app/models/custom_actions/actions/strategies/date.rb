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

module CustomActions::Actions::Strategies::Date
  CURRENT_DATE = "%CURRENT_DATE%"

  # An interval is stored as "<number><unit>" where the unit is one of
  # "d" (days), "w" (weeks), "m" (months) or "y" (years), e.g. "5d".
  # The number is limited to four digits to keep the resulting date sane.
  INTERVAL_PATTERN = /\A([1-9]\d{0,3})([dwmy])\z/

  def values=(values)
    super(Array(values).map { |v| to_date_or_nil(v) }.uniq)
  end

  def type
    :date_property
  end

  def apply(work_package)
    accessor = :"#{self.class.key}="
    if work_package.respond_to? accessor
      work_package.send(accessor, date_to_apply(work_package))
    end
  end

  private

  def date_to_apply(work_package)
    value = values.first

    if interval?(value)
      shift_by_interval(Date.today, value, work_package)
    elsif value == CURRENT_DATE
      Date.today
    else
      value
    end
  end

  # The date an interval is counted from, i.e. the day the action is applied.
  # For all other values there is nothing to count from and the resulting date
  # is used as is.
  def start_date_to_apply(work_package)
    if interval?(values.first)
      WorkPackages::Shared::Days.for(work_package).soonest_working_day(Date.today)
    else
      date_to_apply(work_package)
    end
  end

  # Shifts the date by the given interval, taking the work package's
  # non-working days into account.
  def shift_by_interval(date, interval, work_package)
    amount, unit = interval.match(INTERVAL_PATTERN).captures
    days = WorkPackages::Shared::Days.for(work_package)

    if unit == "d"
      # Days are counted as working days. #due_date includes the start date in
      # the duration, hence the additional day.
      days.due_date(date, amount.to_i + 1)
    else
      # Weeks, months and years are calendar based. The resulting date is moved
      # to the next working day if it happens to be a non-working one.
      days.soonest_working_day(date + calendar_offset(amount.to_i, unit))
    end
  end

  def calendar_offset(amount, unit)
    case unit
    when "w" then amount.weeks
    when "m" then amount.months
    else amount.years
    end
  end

  def interval?(value)
    value.is_a?(String) && value.match?(INTERVAL_PATTERN)
  end

  def to_date_or_nil(value)
    if value.nil? || value == CURRENT_DATE || interval?(value)
      value
    else
      value.to_date
    end
  rescue TypeError, ArgumentError
    nil
  end
end
