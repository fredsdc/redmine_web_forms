class Webform < ActiveRecord::Base
  include Redmine::SafeAttributes

  has_many :webform_custom_field_values, :dependent => :delete_all
  has_many :custom_fields, :through => :webform_custom_field_values

  has_many :questions, lambda {order(:position)}
  has_many :custom_fields, :through => :questions

  belongs_to :project
  belongs_to :tracker
  belongs_to :group
  belongs_to :role
  belongs_to :issue_status

  validates_presence_of :title

  safe_attributes(
    'title',
    'description',
    'project_id',
    'tracker_id',
    'group_id',
    'role_id',
    'issue_status_id',
    'questions')

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
        role_id: roles.pluck(:id),
        workspace_id: self.project.workspace_id
      ).pluck(:new_status_id).include?(self.issue_status_id)
  end

  private

  def can_add_issue(role)
    role.has_permission?(:add_issues) &&
    (
      role.permissions_all_trackers?(:add_issues) ||
      role.permissions_tracker_ids(:add_issues).include?(self.tracker_id)
    )
  end
end
