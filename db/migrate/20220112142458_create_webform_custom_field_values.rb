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

class CreateWebformCustomFieldValues < ActiveRecord::Migration[5.2]
  def change
    create_table :webform_custom_field_values do |t|
      t.integer :webform_id, :null => false
      t.integer :custom_field_id
      t.text :identifier
      t.integer :position, :default => nil, :null => true
      t.text :default_value
    end
    add_index :webform_custom_field_values, [:webform_id, :custom_field_id], :unique => true, :name => :webform_custom_field_values_ids
  end
end
