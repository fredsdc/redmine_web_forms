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

# Create table if not migrated
class CreateWebformQuestions < ActiveRecord::Migration[5.2]
  def self.up
    unless ActiveRecord::Base.connection.table_exists?(:webform_questions)
      create_table :webform_questions do |t|
        t.integer :webform_id, :null => false
        t.integer :custom_field_id
        t.string :identifier
        t.text :description
        t.integer :position, :default => nil, :null => true
        t.text :possible_values
        t.boolean :hidden, :default => 0
        t.boolean :required, :default => 0
        t.text :onchange
      end
    end
  end
  def self.down
    drop_table :webform_questions
  end
end
