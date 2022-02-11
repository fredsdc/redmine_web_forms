class Webform < ActiveRecord::Base
  include Redmine::SafeAttributes

  has_many :webform_custom_field_values, -> {order(:position)}, :dependent => :delete_all
  has_many :questions, -> {order(:position)}, :dependent => :delete_all

  belongs_to :project
  belongs_to :tracker
  belongs_to :group
  belongs_to :role
  belongs_to :issue_status

  validates_presence_of :title
  validate :identifier_uniqueness

  safe_attributes(
    'title',
    'description',
    'project_id',
    'tracker_id',
    'group_id',
    'role_id',
    'issue_status_id',
    'questions',
    'webform_custom_field_values')

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
        role_id: roles.map{|r| r.id},
        workspace_id: self.project.workspace_id
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

  def identifier_uniqueness
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
