class WebformCustomFieldValue < ActiveRecord::Base
  include Redmine::SafeAttributes

  belongs_to :webform
  belongs_to :custom_field

  safe_attributes(
    'custom_field_id',
    'identifier',
    'value',
  )

  def customized
    false
  end
end
