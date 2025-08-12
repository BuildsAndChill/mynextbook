class AddUserToReadings < ActiveRecord::Migration[8.0]
  def up
    # First, create a default user if none exists
    if User.count == 0
      default_user = User.create!(
        email: 'default@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      )
    else
      default_user = User.first
    end

    # Add the user_id column (nullable first)
    add_reference :readings, :user, null: true, foreign_key: true

    # Update existing readings to use the default user
    Reading.where(user_id: nil).update_all(user_id: default_user.id)

    # Make the column not nullable
    change_column_null :readings, :user_id, false
  end

  def down
    remove_reference :readings, :user, foreign_key: true
  end
end
