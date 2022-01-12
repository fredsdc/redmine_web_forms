class CreateWebforms < ActiveRecord::Migration[5.2]
  def change
    create_table :webforms do |t|
      t.string :title
      t.text :description
      t.integer :project_id
      t.integer :tracker_id
      t.integer :group_id
      t.integer :role_id
    end
  end
end
