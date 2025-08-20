class CreateSubscriberInteractions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriber_interactions do |t|
      t.references :subscriber, null: false, foreign_key: true
      t.string :context
      t.text :tone_chips
      t.text :ai_response
      t.text :parsed_response
      t.string :session_id
      t.integer :interaction_number

      t.timestamps
    end
  end
end
