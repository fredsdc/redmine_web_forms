class CreateQuestions < ActiveRecord::Migration[5.2]
  def change
    create_table :questions do |t|
      t.integer :webform_id, :null => false
      t.integer :custom_field_id
      t.string :identifier
      t.text :description
      t.integer :position, :default => nil, :null => true
      t.text :possible_values
      t.boolean :hidden, :default => 0
      t.text :onchange
    end
  end
end
