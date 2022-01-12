class CreateQuestions < ActiveRecord::Migration[5.2]
  def change
    create_table :questions do |t|
      t.text :description
      t.integer :custom_field_id
    end
  end
end
