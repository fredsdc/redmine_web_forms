# Redmine Web Forms - A Redmine Plugin
# Copyright (C) 2022  Frederico Camara
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

class CreateWebforms < ActiveRecord::Migration[5.2]
  def change
    create_table :webforms do |t|
      t.string :title
      t.text :description
      t.integer :project_id
      t.integer :tracker_id
      t.integer :group_id
      t.integer :role_id
      t.integer :issue_status_id
    end
  end
end
