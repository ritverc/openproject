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
import { setupStimulusTest, type StimulusTestContext } from 'core-stimulus/test-helpers';
import FieldGroupPermissionsOtherController from './field-group-permissions-other.controller';

describe('FieldGroupPermissionsOtherController', () => {
  let ctx:StimulusTestContext;

  const template = (action:string) => `
    <div data-controller="field-group-permissions-other">
      <button type="button"
              data-action="field-group-permissions-other#apply"
              data-field-group-permissions-other-action-value="${action}">Quick</button>
      <input type="checkbox" id="hidden_1_other">
      <input type="checkbox" id="hidden_2_other">
      <input type="checkbox" id="read_only_1_other">
      <input type="checkbox" id="read_only_2_other">
      <input type="checkbox" id="hidden_1_author">
    </div>
  `;

  beforeEach(async () => {
    ctx = await setupStimulusTest({
      controllers: {
        'field-group-permissions-other': FieldGroupPermissionsOtherController,
      },
    });
  });

  afterEach(() => ctx.dispose());

  it("sets Hide + Read-only on every 'other' checkbox when deny is clicked", async () => {
    await ctx.mount(template('deny'));

    ctx.screen.getByRole('button', { name: 'Quick' }).click();
    await ctx.nextFrame();

    expect(ctx.container.querySelector('#hidden_1_other')).toBeChecked();
    expect(ctx.container.querySelector('#hidden_2_other')).toBeChecked();
    expect(ctx.container.querySelector('#read_only_1_other')).toBeChecked();
    expect(ctx.container.querySelector('#read_only_2_other')).toBeChecked();
    // an unrelated role checkbox must not be touched
    expect(ctx.container.querySelector('#hidden_1_author')).not.toBeChecked();
  });

  it("clears the 'other' checkboxes when allow is clicked", async () => {
    await ctx.mount(template('allow'));

    ctx.screen.getByRole('button', { name: 'Quick' }).click();
    await ctx.nextFrame();

    expect(ctx.container.querySelector('#hidden_1_other')).not.toBeChecked();
    expect(ctx.container.querySelector('#read_only_1_other')).not.toBeChecked();
  });
});
