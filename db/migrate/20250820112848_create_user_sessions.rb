class CreateUserSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :user_sessions do |t|
      t.string :session_identifier
      t.text :device_info
      t.text :user_agent
      t.string :ip_address
      t.datetime :last_activity

      t.timestamps
    end
  end
end
