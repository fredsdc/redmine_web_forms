class Question < ActiveRecord::Base
  belongs_to :webform
  belongs_to :custom_field

  acts_as_positioned

  scope :sorted, lambda { order(:position) }

end
