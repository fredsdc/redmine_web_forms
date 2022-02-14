class Question < ActiveRecord::Base
  include Redmine::SafeAttributes

  belongs_to :webform
  belongs_to :custom_field, lambda { where :type => "IssueCustomField" }

  acts_as_positioned
  serialize :possible_values

  scope :sorted, lambda { order(:position) }

  validates :custom_field_id, :numericality => { :only_integer => true, :greater_than_or_equal_to => -5, :other_than => 0, :message => :invalid }, :allow_blank => true
  validates_presence_of :custom_field, :if => lambda { custom_field_id.to_i > 0 }
  validates_format_of :identifier, :with => /\A(?!\d+$)[a-z0-9\-_]*\z/

  safe_attributes(
    'custom_field_id',
    'identifier',
    'description',
    'position',
    'possible_values',
    'hidden',
    'onchange'
  )

  def possible_values
    values = read_attribute(:possible_values)
    if values.is_a?(Array)
      values.each do |value|
        value.to_s.force_encoding('UTF-8')
      end
      values
    else
      []
    end
  end

  def possible_values=(arg)
    if arg.is_a?(Array)
      values = arg.compact.map {|a| a.to_s.strip}.reject(&:blank?)
      write_attribute(:possible_values, values)
    else
      self.possible_values = arg.to_s.split(/[\n\r]+/)
    end
  end
end
