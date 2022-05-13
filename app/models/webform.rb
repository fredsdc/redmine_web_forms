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

class Webform < ActiveRecord::Base
  include Redmine::SafeAttributes

  IDENTIFIER_MAX_LENGTH = 100

  has_many :webform_custom_field_values, -> {order(:position)}, :dependent => :delete_all
  has_many :questions, -> {order(:position)}, :dependent => :delete_all

  belongs_to :project
  belongs_to :tracker
  belongs_to :group
  belongs_to :role
  belongs_to :issue_status

  validates_presence_of :title, :identifier
  validates_uniqueness_of :identifier, :if => Proc.new {|p| p.identifier_changed?}
  validates_length_of :identifier, :maximum => IDENTIFIER_MAX_LENGTH
  # downcase letters, digits, dashes but not digits only
  validates_format_of :identifier, :with => /\A(?!\d+$)[a-z0-9\-_]*\z/, :if => Proc.new { |p| p.identifier_changed? }
  # reserved words
  validates_exclusion_of :identifier, :in => %w( new update_selects update_custom_field )
  validate :question_identifier_uniqueness

  safe_attributes(
    'title',
    'description',
    'project_id',
    'tracker_id',
    'group_id',
    'role_id',
    'issue_status_id',
    'questions',
    'webform_custom_field_values',
    'identifier')

  def validate_webform(user=User.current)
      roles = (
        (user.present? ? user.roles_for_project(self.project) : []) |
        (self.role.present? ? [ self.role ] : []) |
        Member.where(user_id: self.group_id, project_id: self.project_id).map{|m| m.roles}
      ).flatten.uniq

      self.project.present? &&
      self.tracker.present? &&
      self.project.trackers.include?(self.tracker) &&
      self.issue_status.present? &&
      roles.map{|role| can_add_issue(role)}.any? &&
      WorkflowTransition.where(
        old_status_id: 0,
        tracker_id: self.tracker_id,
        role_id: roles.map{|r| r.id}
      ).map{|w| w.new_status_id}.include?(self.issue_status_id)
  end

  private

  def can_add_issue(role)
    role.has_permission?(:add_issues) &&
    (
      role.permissions_all_trackers?(:add_issues) ||
      role.permissions_tracker_ids(:add_issues).include?(self.tracker_id)
    )
  end

  def question_identifier_uniqueness
    rep_str = (
      questions.map{|x| x.identifier} +
      webform_custom_field_values.map{|x| x.identifier} -
      ["", nil]
    ).group_by{ |e| e }.select { |k, v| v.size > 1 }.keys.join(", ")

    if rep_str.present?
      errors.add(:webform, l(:error_repeated_identifiers, :identifiers => rep_str))
    end
  end
end
