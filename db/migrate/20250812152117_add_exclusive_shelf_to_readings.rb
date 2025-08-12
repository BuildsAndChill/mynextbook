class AddExclusiveShelfToReadings < ActiveRecord::Migration[8.0]
  def change
    add_column :readings, :exclusive_shelf, :string
  end
end
