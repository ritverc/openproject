/*
 * -- copyright
 * OpenProject is an open source project management software.
 * Copyright (C) the OpenProject GmbH
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License version 3.
 *
 * OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
 * Copyright (C) 2006-2013 Jean-Philippe Lang
 * Copyright (C) 2010-2013 the ChiliProject Team
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 * See COPYRIGHT and LICENSE files for more details.
 * ++
 */

import { Controller } from '@hotwired/stimulus';

/**
 * Applies a quick setting to the whole "other" column of the field group access
 * matrix. The "other" role applies to users who are neither author, assignee nor
 * responsible for the work package.
 *
 * Two buttons drive it through `data-field-group-permissions-other-action-value`:
 * "deny" sets Hide + Read-only on every status row, "allow" clears both. The
 * admin then saves the matrix as usual.
 */
export default class FieldGroupPermissionsOtherController extends Controller {
  apply(event:Event) {
    const button = event.target as HTMLElement | null;
    if (!button) {
      return;
    }

    const deny = button.dataset.fieldGroupPermissionsOtherActionValue === 'deny';
    this.setColumn('hidden', deny);
    this.setColumn('read_only', deny);
  }

  private setColumn(restriction:string, checked:boolean) {
    const selector = `input[id^="${restriction}_"][id$="_other"][type="checkbox"]`;
    this.element.querySelectorAll(selector).forEach((element) => {
      (element as HTMLInputElement).checked = checked;
    });
  }
}
