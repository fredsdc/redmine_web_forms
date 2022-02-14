class Question < ActiveRecord::Base
  include Redmine::SafeAttributes

  belongs_to :webform
  belongs_to :custom_field, lambda { where :type => "IssueCustomField" }

  acts_as_positioned

  scope :sorted, lambda { order(:position) }

  validates :custom_field_id, :numericality => { :only_integer => true, :greater_than_or_equal_to => -5, :other_than => 0, :message => :invalid }, :allow_blank => true
  validates_presence_of :custom_field, :if => lambda { custom_field_id.to_i > 0 }
  validates_format_of :identifier, :with => /\A(?!\d+$)[a-z0-9\-_]*\z/

  safe_attributes(
    'custom_field_id',
    'identifier',
    'description',
    'position',
    'hidden',
    'onchange'
  )
end
