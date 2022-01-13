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

  validates_presence_of :title

  safe_attributes(
    'title',
    'description',
    'project_id',
    'tracker_id',
    'group_id',
    'role_id',
    'questions')
end
