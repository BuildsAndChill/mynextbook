class CreateSubscribers < ActiveRecord::Migration[8.0]
  def change
    create_table :subscribers do |t|
      t.string :email
      t.text :context
      t.text :tone_chips
      t.text :ai_response
      t.text :parsed_response
      t.integer :interaction_count
      t.string :session_id

      t.timestamps
    end
    add_index :subscribers, :email
  end
end
