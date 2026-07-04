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
import { isFieldHiddenByMatrix, isFieldReadonlyByMatrix } from './field-group-restrictions';

function resourceWith(restricted?:{ hidden?:string[], readOnly?:string[] }):HalResource {
  return { $source: restricted ? { restrictedFieldGroups: restricted } : {} } as unknown as HalResource;
}

describe('field group restrictions helper', () => {
  it('returns false when the resource carries no restrictions', () => {
    expect(isFieldReadonlyByMatrix(resourceWith(), 'subject')).toBe(false);
    expect(isFieldHiddenByMatrix(resourceWith(), 'subject')).toBe(false);
  });

  it('detects read-only and hidden attributes independently', () => {
    const resource = resourceWith({ hidden: ['status'], readOnly: ['assignee'] });

    expect(isFieldReadonlyByMatrix(resource, 'assignee')).toBe(true);
    expect(isFieldReadonlyByMatrix(resource, 'status')).toBe(false);
    expect(isFieldHiddenByMatrix(resource, 'status')).toBe(true);
    expect(isFieldHiddenByMatrix(resource, 'assignee')).toBe(false);
  });

  it('expands the combined "date" member to the concrete date fields', () => {
    const resource = resourceWith({ readOnly: ['date'] });

    ['date', 'startDate', 'dueDate', 'combinedDate'].forEach((field) => {
      expect(isFieldReadonlyByMatrix(resource, field)).toBe(true);
    });
    expect(isFieldReadonlyByMatrix(resource, 'subject')).toBe(false);
  });
});
