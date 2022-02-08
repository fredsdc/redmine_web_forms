class CreateWebformCustomFieldValues < ActiveRecord::Migration[5.2]
  def change
    create_table :webform_custom_field_values do |t|
      t.integer :webform_id, :null => false
      t.integer :custom_field_id, :null => false
      t.text :identifier
      t.text :value
    end
    add_index :webform_custom_field_values, [:webform_id, :custom_field_id], :unique => true, :name => :webform_custom_field_values_ids
  end
end
