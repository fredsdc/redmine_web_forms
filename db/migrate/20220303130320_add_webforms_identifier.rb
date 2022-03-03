class AddWebformsIdentifier < ActiveRecord::Migration[4.2]
  def change
    add_column :webforms, :identifier, :string, :limit => 100
  end
end
