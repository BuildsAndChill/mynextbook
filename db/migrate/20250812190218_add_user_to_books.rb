class AddUserToBooks < ActiveRecord::Migration[8.0]
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
    add_reference :books, :user, null: true, foreign_key: true
    
    # Update existing books to use the default user
    Book.where(user_id: nil).update_all(user_id: default_user.id)
    
    # Make the column not nullable
    change_column_null :books, :user_id, false
  end

  def down
    remove_reference :books, :user, foreign_key: true
  end
end
