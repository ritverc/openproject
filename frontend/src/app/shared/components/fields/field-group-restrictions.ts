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

// Field group access matrix restrictions exposed per work package by the API
// (`restrictedFieldGroups`). They let the frontend hide / disable fields already
// on first render, before the (per-work-package) form schema is loaded.
export interface IFieldGroupRestrictions {
  hidden:string[];
  readOnly:string[];
}

// Concrete date field names the combined "date" matrix member expands to.
const dateAliases = ['date', 'startDate', 'dueDate', 'combinedDate'];

function restrictionsOf(resource:HalResource|null|undefined):IFieldGroupRestrictions {
  const source = resource?.$source as { restrictedFieldGroups?:Partial<IFieldGroupRestrictions> }|undefined;
  const raw = source?.restrictedFieldGroups;
  return { hidden: raw?.hidden ?? [], readOnly: raw?.readOnly ?? [] };
}

function restricts(list:string[], fieldName:string):boolean {
  if (list.length === 0) {
    return false;
  }
  if (list.includes(fieldName)) {
    return true;
  }
  return dateAliases.includes(fieldName) && list.includes('date');
}

/** Whether the field group access matrix marks the attribute read-only. */
export function isFieldReadonlyByMatrix(resource:HalResource, fieldName:string):boolean {
  return restricts(restrictionsOf(resource).readOnly, fieldName);
}

/** Whether the field group access matrix marks the attribute hidden. */
export function isFieldHiddenByMatrix(resource:HalResource, fieldName:string):boolean {
  return restricts(restrictionsOf(resource).hidden, fieldName);
}
