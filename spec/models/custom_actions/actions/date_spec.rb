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

require "spec_helper"
require_relative "../shared_expectations"

RSpec.describe CustomActions::Actions::Date do
  let(:key) { :date }
  let(:type) { :date_property }
  let(:value) { Date.today }

  it_behaves_like "base custom action" do
    describe "#apply" do
      let(:work_package) { build_stubbed(:work_package) }

      it "sets both start and finish date to the action's value" do
        instance.values = [Date.today + 5]

        instance.apply(work_package)

        expect(work_package.start_date)
          .to eql Date.today + 5
        expect(work_package.due_date)
          .to eql Date.today + 5
      end

      it "sets both start and finish date to the current date if so specified" do
        instance.values = ["%CURRENT_DATE%"]

        instance.apply(work_package)

        expect(work_package.start_date)
          .to eql Date.today
        expect(work_package.due_date)
          .to eql Date.today
      end

      it "clears both start and finish date if no value is set" do
        work_package.start_date = Date.today
        work_package.due_date = Date.today

        instance.values = [nil]

        instance.apply(work_package)

        expect(work_package.start_date)
          .to be_nil
        expect(work_package.due_date)
          .to be_nil
      end

      context "with an interval" do
        before do
          week_with_saturday_and_sunday_as_weekend
        end

        it "starts on the current date and is due after the interval in working days" do
          # 2024-01-01 is a Monday
          travel_to(Date.new(2024, 1, 1)) do
            instance.values = ["5d"]

            instance.apply(work_package)

            expect(work_package.start_date)
              .to eql Date.new(2024, 1, 1)
            expect(work_package.due_date)
              .to eql Date.new(2024, 1, 8)
          end
        end

        it "skips non-working days (two days after a Friday is the next Tuesday)" do
          # 2024-01-05 is a Friday
          travel_to(Date.new(2024, 1, 5)) do
            instance.values = ["2d"]

            instance.apply(work_package)

            expect(work_package.start_date)
              .to eql Date.new(2024, 1, 5)
            expect(work_package.due_date)
              .to eql Date.new(2024, 1, 9)
          end
        end

        it "starts on the next working day if the current date is a non-working one" do
          # 2024-01-06 is a Saturday
          travel_to(Date.new(2024, 1, 6)) do
            instance.values = ["2d"]

            instance.apply(work_package)

            expect(work_package.start_date)
              .to eql Date.new(2024, 1, 8)
            expect(work_package.due_date)
              .to eql Date.new(2024, 1, 10)
          end
        end

        it "adds weeks, months and years as calendar time" do
          travel_to(Date.new(2024, 1, 1)) do
            instance.values = ["1w"]
            instance.apply(work_package)
            expect(work_package.due_date).to eql Date.new(2024, 1, 8)

            instance.values = ["1m"]
            instance.apply(work_package)
            expect(work_package.due_date).to eql Date.new(2024, 2, 1)

            instance.values = ["1y"]
            instance.apply(work_package)
            expect(work_package.due_date).to eql Date.new(2025, 1, 1)
          end
        end

        it "moves a calendar interval landing on a non-working day to the next working day" do
          # 2024-01-03 + 1 month is Saturday 2024-02-03
          travel_to(Date.new(2024, 1, 3)) do
            instance.values = ["1m"]

            instance.apply(work_package)

            expect(work_package.due_date)
              .to eql Date.new(2024, 2, 5)
          end
        end

        context "when the work package ignores non-working days" do
          let(:work_package) { build_stubbed(:work_package, ignore_non_working_days: true) }

          it "counts days as calendar days" do
            travel_to(Date.new(2024, 1, 5)) do
              instance.values = ["2d"]

              instance.apply(work_package)

              expect(work_package.start_date)
                .to eql Date.new(2024, 1, 5)
              expect(work_package.due_date)
                .to eql Date.new(2024, 1, 7)
            end
          end
        end
      end
    end

    describe "#multi_value?" do
      it "is false" do
        expect(instance)
          .not_to be_multi_value
      end
    end
  end
end
