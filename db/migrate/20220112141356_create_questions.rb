class CreateQuestions < ActiveRecord::Migration[5.2]
  def change
    create_table :questions do |t|
      t.integer :webform_id, :null => false
      t.integer :custom_field_id
      t.text :identifier
      t.text :description
      t.integer :position, :default => nil, :null => true
      t.boolean :hidden, :default => 0
      t.string :unhide_if
    end
  end
end
