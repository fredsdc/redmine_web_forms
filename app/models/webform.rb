class Webform < ActiveRecord::Base
  include Redmine::SafeAttributes

  has_many :webform_questions, :dependent => :delete_all
  has_many :webform_custom_field_values, :dependent => :delete_all

  has_many :questions, lambda {order(:position)}
  has_many :custom_fields, :through => :questions
  has_many :custom_fields, :through => :webform_custom_field_values

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
    self.project.present? &&
      self.tracker.present? &&
      Role.find(roles(user)).map{|r| can_add_issue(r)}.any? &&
      initial_status_allowed(user)
  end

  private

  def initial_status_allowed(user=User.current)
    self.project.present? &&
      self.issue_status.present? &&
      self.tracker.present? &&
      WorkflowTransition.where(old_status_id: 0, tracker_id: self.tracker_id, role_id: roles(user), workspace_id: self.project.workspace_id).
        pluck(:new_status_id).include?(self.issue_status_id)
  end

  def roles(user=User.current)
    if self.project.present?
      user.roles_for_project(self.project).pluck(:id) |
        ( self.role.present? ? [ self.role_id ] : [] ) |
        self.project.memberships.where(user_id: self.group_id).map{|m| m.roles}.flatten.pluck(:id)
    else
      []
    end
  end

  def can_add_issue(role)
    role.has_permission?(:add_issues) &&
    ( role.permissions_all_trackers?(:add_issues) ||
    role.permissions_tracker_ids(:add_issues).include?(self.tracker_id))
  end
end
