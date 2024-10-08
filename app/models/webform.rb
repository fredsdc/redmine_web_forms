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
  has_many :webform_questions, -> {order(:position)}, :dependent => :delete_all

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
  validate :webform_question_identifier_uniqueness

  safe_attributes(
    'title',
    'description',
    'project_id',
    'tracker_id',
    'group_id',
    'role_id',
    'issue_status_id',
    'webform_questions',
    'webform_custom_field_values',
    'identifier',
    'allow_attachments',
    'use_user_id',
    'ready',
    'submit',
    'functions'
  )

  def validate_webform(user=User.current)
    user = User.find(self.use_user_id) if self.use_user_id.present?
    roles = get_user_roles(user)

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

  def validate_webform_errors(user=User.current)
    user = User.find(self.use_user_id) if self.use_user_id.present?
    roles = get_user_roles(user)

    errors = []
    errors += [l(:error_webform_no_project)] unless self.project.present?
    errors += [l(:error_webform_no_tracker)] unless self.tracker.present?
    errors += [l(:error_webform_no_tracker_in_project)] unless self.project.trackers.include?(self.tracker) if errors.empty?
    errors += [l(:error_webform_no_issue_status)] unless self.issue_status.present?
    errors += [l(:error_webform_no_workflow)] unless WorkflowTransition.where(
                                                        old_status_id: 0,
                                                        tracker_id: self.tracker_id,
                                                        role_id: roles.map{|r| r.id}
                                                      ).map{|w| w.new_status_id}.include?(self.issue_status_id) if errors.empty?
    errors += [l(:error_webform_roles_cant_add_issue)] unless roles.map{|role| can_add_issue(role)}.any?
    errors
  end

  def can_add_attachments(user=User.current)
    roles = get_user_roles(user)

    roles.map{|role|
      role.has_permission?(:add_attachments) &&
      (
        role.permissions_all_trackers?(:add_attachments) ||
        role.permissions_tracker_ids(:add_attachments).include?(self.tracker_id)
      )
    }.any?
  end

  def validate_webform_fs_errors
    ufs = find_unavailable_fs
    ufs.present? ? [l(:notice_no_role_for_custom_field, :ifs => ufs)] : []
  end

  private

  def can_add_issue(role)
    role.has_permission?(:add_issues) &&
    (
      role.permissions_all_trackers?(:add_issues) ||
      role.permissions_tracker_ids(:add_issues).include?(self.tracker_id)
    )
  end

  def get_user_roles(user)
    (
      if self.project.present? && user.present?
        if user.admin?
          self.project.members.map{|m| m.roles}
        else
          User.find(user.id).roles_for_project(self.project)
        end
      else
        []
      end |
      (self.role.present? ? [ self.role ] : []) |
      Member.where(user_id: self.group_id, project_id: self.project_id).map{|m| m.roles}
    ).flatten.uniq
  end

  def webform_question_identifier_uniqueness
    rep_str = (
      webform_questions.map{|x| x.identifier} +
      webform_custom_field_values.map{|x| x.identifier} -
      ["", nil]
    ).group_by{ |e| e }.select { |k, v| v.size > 1 }.keys.join(", ")

    if rep_str.present?
      errors.add(:webform, l(:error_repeated_identifiers, :identifiers => rep_str))
    end
  end

  def find_unavailable_fs
    roles = (Member.where(user_id: self.group_id, project_id: self.project_id).map{|m| m.roles.ids}.flatten | [self.role_id] | (self.use_user_id.present? ? User.find(self.use_user_id).roles.ids : [])).compact.presence
    if roles.present?
      # Fields on webform
      fs = (
        self.webform_custom_field_values.map(&:custom_field_id) +
        self.webform_questions.map(&:custom_field_id)
      ).compact.uniq

      # Available fields on project
      afs = self.tracker.custom_field_ids & self.project.issue_custom_field_ids &
        (CustomField.find(fs.select{|i| i.to_i > 0}).select(&:visible).pluck(:id) |
         CustomField.find(fs.select{|i| i.to_i > 0}).select{|cf| (cf.role_ids & roles).any?}.pluck(:id))

      # Read only custom fields on project
      rofs = WorkflowPermission.where(
               tracker_id: self.tracker_id,
               role_id: roles,
               old_status_id: self.issue_status_id,
               rule: "readonly").pluck(:field_name,:role_id
             ).reduce({}){|h, (k, v)| nk=cf_name_to_index(k); (h[nk] ||= []) << v; h}.reject{|k| k.nil?}

      fs.map do |cf|
        if ((cf > 0) & ! afs.include?(cf)) | (rofs[cf].present? && (roles - rofs[cf]).empty?)
          cf > 0 ? "#{cf_index_to_name(cf)} (#{cf})" : "#{l("field_" + cf_index_to_name(cf).gsub(/_id$/, ""))}"
        end
      end.compact.join(", ").presence
    end
  end

  def cf_name_to_index(i)
    if i.to_i == 0
      case i
      when "assigned_to_id"; -1
      when "category_id"; -2
      when "description"; -3
      when "subject"; -4
      when "fixed_version_id"; -5
      when "priority_id"; -6
      when "parent_issue_id"; -7
      when "start_date"; -8
      when "due_date"; -9
      when "done_ratio"; -10
      else;    nil
      end
    else
      i.to_i
    end
  end

  def cf_index_to_name(i)
    if i < 0
      case i
      when -1; "assigned_to_id"
      when -2; "category_id"
      when -3; "description"
      when -4; "subject"
      when -5; "fixed_version_id"
      when -6; "priority_id"
      when -7; "parent_issue_id"
      when -8; "start_date"
      when -9; "due_date"
      when -10; "done_ratio"
      else;    nil
      end
    else
      CustomField.find(i).name
    end
  end
end
