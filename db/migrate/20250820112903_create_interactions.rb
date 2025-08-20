class CreateInteractions < ActiveRecord::Migration[8.0]
  def change
    create_table :interactions do |t|
      t.references :user_session, null: false, foreign_key: true
      t.string :action_type
      t.json :action_data
      t.string :context
      t.json :metadata
      t.datetime :timestamp

      t.timestamps
    end
  end
end
