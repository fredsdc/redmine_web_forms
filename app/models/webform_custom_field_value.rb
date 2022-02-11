class WebformCustomFieldValue < ActiveRecord::Base
  include Redmine::SafeAttributes

  belongs_to :webform
  belongs_to :custom_field, lambda { where :type => "IssueCustomField" }

  acts_as_positioned

  scope :sorted, lambda { order(:position) }

  validates :custom_field_id, :numericality => { :only_integer => true, :greater_than_or_equal_to => -5, :other_than => 0, :message => :invalid }, :allow_blank => true
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
