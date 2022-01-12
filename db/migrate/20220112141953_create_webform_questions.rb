class CreateWebformQuestions < ActiveRecord::Migration[5.2]
  def change
    create_table :webform_questions, :id => false do |t|
      t.integer :webform_id, :null => false
      t.integer :question_id, :null => false
      t.integer :position, :default => nil, :null => true
      t.boolean :hidden, :default => 0
      t.string :unhide_if
    end
    add_index :webform_questions, [:webform_id, :question_id], :unique => true, :name => :webform_questions_ids
  end
end
