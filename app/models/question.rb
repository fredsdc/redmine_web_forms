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

class Question < ActiveRecord::Base
  include Redmine::SafeAttributes

  belongs_to :webform
  belongs_to :custom_field, lambda { where :type => "IssueCustomField" }

  acts_as_positioned
  serialize :possible_values

  scope :sorted, lambda { order(:position) }

  validates :custom_field_id, :numericality => { :only_integer => true, :greater_than_or_equal_to => -5, :other_than => 0, :message => :invalid }, :allow_blank => true
  validates_presence_of :custom_field, :if => lambda { custom_field_id.to_i > 0 }
  validates_format_of :identifier, :with => /\A(?!\d+$)[a-z0-9\-_]*\z/

  safe_attributes(
    'custom_field_id',
    'identifier',
    'description',
    'position',
    'possible_values',
    'hidden',
    'onchange'
  )

  def possible_values
    values = read_attribute(:possible_values)
    if values.is_a?(Array)
      values.each do |value|
        value.to_s.force_encoding('UTF-8')
      end
      values
    else
      []
    end
  end

  def possible_values=(arg)
    if arg.is_a?(Array)
      values = arg.compact.map {|a| a.to_s.strip}.reject(&:blank?)
      write_attribute(:possible_values, values)
    else
      self.possible_values = arg.to_s.split(/[\n\r]+/)
    end
  end
end
