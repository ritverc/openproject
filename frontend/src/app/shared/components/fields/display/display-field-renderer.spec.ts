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

import { HalResource } from 'core-app/features/hal/resources/hal-resource';
import { DisplayFieldService } from 'core-app/shared/components/fields/display/display-field.service';
import { SchemaCacheService } from 'core-app/core/schemas/schema-cache.service';
import { HalResourceEditingService } from 'core-app/shared/components/fields/edit/services/hal-resource-editing.service';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import { ConfigurationService } from 'core-app/core/config/configuration.service';
import {
  DisplayFieldRenderer,
  editableClassName,
  readOnlyClassName,
} from './display-field-renderer';

describe('DisplayFieldRenderer inline editing gating', () => {
  let inlineEditingEnabled:boolean;

  const persisted = { id: '42' } as unknown as HalResource;
  const freshResource = { id: 'new' } as unknown as HalResource;

  function buildRenderer(container:'table'|'single-view'|'timeline'):DisplayFieldRenderer {
    const fieldStub = {
      render: (span:HTMLElement, text:string):void => { span.textContent = text; },
      apply: ():void => undefined,
      isEmpty: ():boolean => false,
      valueString: 'Value',
      placeholder: '-',
      required: false,
      writable: true,
      name: 'subject',
      displayName: 'Subject',
      isFormattable: false,
      title: '',
      activeChange: null,
    };

    const schemaStub = {
      ofProperty: () => ({ options: {}, writable: true, name: 'subject' }),
      isAttributeEditable: ():boolean => true,
    };

    const services = new Map<unknown, unknown>([
      [DisplayFieldService, { getField: () => fieldStub }],
      [SchemaCacheService, { of: () => schemaStub }],
      [HalResourceEditingService, { typedState: () => ({ hasValue: () => false }) }],
      [I18nService, { t: (key:string):string => key }],
      [ConfigurationService, {
        get workPackageInlineEditingEnabled():boolean { return inlineEditingEnabled; },
      }],
    ]);

    const injector = { get: (token:unknown):unknown => services.get(token) };

    return new DisplayFieldRenderer(injector, container);
  }

  it('renders persisted table cells read-only when inline editing is disabled', () => {
    inlineEditingEnabled = false;

    const span = buildRenderer('table').render(persisted, 'subject', null);

    expect(span.classList.contains(readOnlyClassName)).toBe(true);
    expect(span.classList.contains(editableClassName)).toBe(false);
    expect(span.getAttribute('role')).toBeNull();
  });

  it('keeps persisted table cells editable when inline editing is enabled', () => {
    inlineEditingEnabled = true;

    const span = buildRenderer('table').render(persisted, 'subject', null);

    expect(span.classList.contains(editableClassName)).toBe(true);
    expect(span.classList.contains(readOnlyClassName)).toBe(false);
    expect(span.getAttribute('role')).toBe('button');
  });

  it('does not affect the single-view container when inline editing is disabled', () => {
    inlineEditingEnabled = false;

    const span = buildRenderer('single-view').render(persisted, 'subject', null);

    expect(span.classList.contains(editableClassName)).toBe(true);
  });

  it('keeps new (unsaved) resources editable in the table so inline creation works', () => {
    inlineEditingEnabled = false;

    const span = buildRenderer('table').render(freshResource, 'subject', null);

    expect(span.classList.contains(editableClassName)).toBe(true);
  });
});
