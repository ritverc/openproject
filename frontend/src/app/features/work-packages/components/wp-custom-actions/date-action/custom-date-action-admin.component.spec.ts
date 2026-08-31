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

import { CUSTOM_ELEMENTS_SCHEMA } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { FormsModule } from '@angular/forms';
import { By } from '@angular/platform-browser';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import { CustomDateActionAdminComponent } from './custom-date-action-admin.component';

describe('CustomDateActionAdminComponent', () => {
  let fixture:ComponentFixture<CustomDateActionAdminComponent>;
  let component:CustomDateActionAdminComponent;

  const getOperatorSelect = () =>
    fixture.debugElement.query(By.css('select')).nativeElement as HTMLSelectElement;

  const getHiddenInput = () =>
    fixture.debugElement.query(By.css('input[type="hidden"]')).nativeElement as HTMLInputElement;

  const getIntervalInput = () =>
    fixture.debugElement.query(By.css('input[type="number"]')).nativeElement as HTMLInputElement;

  const getUnitSelect = () =>
    fixture.debugElement.queryAll(By.css('select'))[1].nativeElement as HTMLSelectElement;

  const selectOperator = (key:string) => {
    getOperatorSelect().value = key;
    getOperatorSelect().dispatchEvent(new Event('change'));
    fixture.detectChanges();
  };

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [CustomDateActionAdminComponent],
      imports: [FormsModule],
      providers: [
        {
          provide: I18nService,
          useValue: {
            t:(key:string) => {
              switch (key) {
                case 'js.custom_actions.date.specific':
                  return 'on';
                case 'js.custom_actions.date.current_date':
                  return 'Current date';
                case 'js.custom_actions.date.interval':
                  return 'after';
                case 'js.custom_actions.date.units.days':
                  return 'Days';
                case 'js.custom_actions.date.units.weeks':
                  return 'Weeks';
                case 'js.custom_actions.date.units.months':
                  return 'Months';
                case 'js.custom_actions.date.units.years':
                  return 'Years';
                default:
                  return key;
              }
            },
          },
        },
      ],
      schemas: [CUSTOM_ELEMENTS_SCHEMA],
    }).compileComponents();

    fixture = TestBed.createComponent(CustomDateActionAdminComponent);
    component = fixture.componentInstance;
    fixture.nativeElement.dataset.fieldName = 'custom_action[actions][date]';
  });

  it('stores the current date sentinel when the operator is changed to current date', () => {
    fixture.detectChanges();

    selectOperator('current');

    expect(component.selectedOperatorKey).toBe('current');
    expect(getHiddenInput().value).toBe('%CURRENT_DATE%');
  });

  it('defaults to a one-day interval and stores value plus unit when switched to interval', () => {
    fixture.detectChanges();

    selectOperator('interval');

    expect(component.selectedOperatorKey).toBe('interval');
    expect(component.intervalValue).toBe(1);
    expect(component.intervalUnit).toBe('d');
    expect(getHiddenInput().value).toBe('1d');
  });

  it('updates the stored value when the interval number changes', () => {
    fixture.detectChanges();

    selectOperator('interval');

    getIntervalInput().value = '5';
    getIntervalInput().dispatchEvent(new Event('input'));
    fixture.detectChanges();

    expect(component.intervalValue).toBe(5);
    expect(getHiddenInput().value).toBe('5d');
  });

  it('keeps the stored interval within the allowed bounds', () => {
    fixture.detectChanges();

    selectOperator('interval');

    getIntervalInput().value = '0';
    getIntervalInput().dispatchEvent(new Event('input'));
    fixture.detectChanges();

    expect(getHiddenInput().value).toBe('1d');

    getIntervalInput().value = '99999';
    getIntervalInput().dispatchEvent(new Event('input'));
    fixture.detectChanges();

    expect(getHiddenInput().value).toBe('9999d');
  });

  it('updates the stored value when the interval unit changes', () => {
    fixture.detectChanges();

    selectOperator('interval');

    getUnitSelect().value = 'w';
    getUnitSelect().dispatchEvent(new Event('change'));
    fixture.detectChanges();

    expect(component.intervalUnit).toBe('w');
    expect(getHiddenInput().value).toBe('1w');
  });

  it('restores number and unit when editing an existing interval', () => {
    fixture.nativeElement.dataset.fieldValue = '3m';

    fixture.detectChanges();

    expect(component.selectedOperatorKey).toBe('interval');
    expect(component.intervalValue).toBe(3);
    expect(component.intervalUnit).toBe('m');
    expect(getHiddenInput().value).toBe('3m');
  });

  it('drops the interval when switching back to a specific date', () => {
    fixture.nativeElement.dataset.fieldValue = '3m';

    fixture.detectChanges();

    selectOperator('on');

    expect(component.selectedOperatorKey).toBe('on');
    expect(getHiddenInput().value).toBe('');
  });

  it('drops the current date sentinel when switching back to a specific date', () => {
    fixture.detectChanges();

    selectOperator('current');
    selectOperator('on');

    expect(getHiddenInput().value).toBe('');
  });

  it('keeps an existing date when switching between operators and back', () => {
    fixture.nativeElement.dataset.fieldValue = '2024-01-05';

    fixture.detectChanges();

    expect(component.selectedOperatorKey).toBe('on');
    expect(getHiddenInput().value).toBe('2024-01-05');
  });
});
