class WebformCustomFieldValue < ActiveRecord::Base
  belongs_to :webform
  belongs_to :custom_field
end
