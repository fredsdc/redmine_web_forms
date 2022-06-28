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

class WebformCustomFieldValue < ActiveRecord::Base
  include Redmine::SafeAttributes

  belongs_to :webform
  belongs_to :custom_field, lambda { where :type => "IssueCustomField" }

  acts_as_positioned

  scope :sorted, lambda { order(:position) }

  validates :custom_field_id, :numericality => { :only_integer => true, :greater_than_or_equal_to => -7, :other_than => 0, :message => :invalid }, :allow_blank => true
  validates_presence_of :custom_field, :if => lambda { custom_field_id.to_i > 0 }
  validates_format_of :identifier, :with => /\A(?!\d+$)[a-z0-9\-_]*\z/
  validate :default_value_is_valid

  safe_attributes(
    'custom_field_id',
    'identifier',
    'position',
    'default_value'
  )

  def customized
    false
  end

  def value
    self.default_value
  end

  private

  def default_value_is_valid
    if custom_field.present?
      ret = true
      custom_field.validate_field_value(default_value).each do |err|
        errors.add(:default_value, err)
        ret = false
      end

      ret
    else
      true
    end
  end
end
