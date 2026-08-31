//-- copyright
// OpenProject is an open source project management software.
// Copyright (C) the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See COPYRIGHT and LICENSE files for more details.
//++

import {
  ApplicationRef,
  ChangeDetectionStrategy,
  ChangeDetectorRef,
  Component,
  ElementRef,
  inject,
  OnInit,
} from '@angular/core';
import { I18nService } from 'core-app/core/i18n/i18n.service';

// An interval is stored as "<number><unit>", e.g. "5d".
// Kept in sync with CustomActions::Actions::Strategies::Date::INTERVAL_PATTERN.
export const INTERVAL_PATTERN = /^([1-9]\d{0,3})([dwmy])$/;

export const MIN_INTERVAL_VALUE = 1;

export const MAX_INTERVAL_VALUE = 9999;

@Component({
  selector: 'opce-custom-date-action-admin',
  templateUrl: './custom-date-action-admin.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: false,
})
export class CustomDateActionAdminComponent implements OnInit {
  public valueVisible = false;

  public fieldName = '';

  public fieldValue = '';

  public visibleValue = '';

  public intervalValue = 1;

  public intervalUnit = 'd';

  private onKey = 'on';

  private currentKey = 'current';

  public intervalKey = 'interval';

  public minIntervalValue = MIN_INTERVAL_VALUE;

  public maxIntervalValue = MAX_INTERVAL_VALUE;

  private currentFieldValue = '%CURRENT_DATE%';

  private elementRef = inject<ElementRef<HTMLElement>>(ElementRef);
  private cdRef = inject(ChangeDetectorRef);
  public appRef = inject(ApplicationRef);
  private I18n = inject(I18nService);

  public intervalUnits = [
    { key: 'd', label: this.I18n.t('js.custom_actions.date.units.days') },
    { key: 'w', label: this.I18n.t('js.custom_actions.date.units.weeks') },
    { key: 'm', label: this.I18n.t('js.custom_actions.date.units.months') },
    { key: 'y', label: this.I18n.t('js.custom_actions.date.units.years') },
  ];

  public selectedOperatorKey = this.onKey;

  public operators = [
    { key: this.onKey, label: this.I18n.t('js.custom_actions.date.specific') },
    { key: this.currentKey, label: this.I18n.t('js.custom_actions.date.current_date') },
    { key: this.intervalKey, label: this.I18n.t('js.custom_actions.date.interval') },
  ];

  // cannot use $onInit as it would be called before the operators gets filled
  public ngOnInit() {
    const element = this.elementRef.nativeElement;
    this.fieldName = element.dataset.fieldName! || '';
    this.fieldValue = element.dataset.fieldValue! || '';

    const intervalMatch = INTERVAL_PATTERN.exec(this.fieldValue);

    if (this.fieldValue === this.currentFieldValue) {
      this.selectedOperatorKey = this.currentKey;
    } else if (intervalMatch) {
      const [, amount, unit] = intervalMatch;

      this.selectedOperatorKey = this.intervalKey;
      this.intervalValue = parseInt(amount, 10);
      this.intervalUnit = unit;
    } else {
      this.selectedOperatorKey = this.onKey;
      this.visibleValue = this.fieldValue;
    }

    this.toggleValueVisibility();
    this.cdRef.markForCheck();
  }

  public toggleValueVisibility() {
    this.valueVisible = this.selectedOperatorKey === this.onKey;

    // The sentinel and interval values are no valid dates, so they must not be
    // carried over when switching back to a specific date.
    if (this.valueVisible && !this.isDate(this.fieldValue)) {
      this.fieldValue = '';
    }

    this.updateDbValue();
    this.cdRef.detectChanges();
  }

  private updateDbValue() {
    if (this.selectedOperatorKey === this.currentKey) {
      this.fieldValue = this.currentFieldValue;
    } else if (this.selectedOperatorKey === this.intervalKey) {
      this.fieldValue = `${this.boundedIntervalValue()}${this.intervalUnit}`;
    }
  }

  private boundedIntervalValue():number {
    return Math.min(Math.max(this.intervalValue, MIN_INTERVAL_VALUE), MAX_INTERVAL_VALUE);
  }

  public get fieldId() {
    // replace all square brackets by underscore
    // to match the label's for value
    return this.fieldName
      .replace(/\[|\]/g, '_')
      .replace('__', '_')
      .replace(/_$/, '');
  }

  public updateField(val:string) {
    this.fieldValue = val;
    this.cdRef.detectChanges();
  }

  public updateIntervalValue(val:string) {
    const parsed = parseInt(val, 10);
    this.intervalValue = Number.isNaN(parsed) ? MIN_INTERVAL_VALUE : parsed;
    this.updateDbValue();
    this.cdRef.detectChanges();
  }

  public updateIntervalUnit(unit:string) {
    this.intervalUnit = unit;
    this.updateDbValue();
    this.cdRef.detectChanges();
  }

  private isDate(value:string):boolean {
    return value !== this.currentFieldValue && !INTERVAL_PATTERN.test(value);
  }
}
