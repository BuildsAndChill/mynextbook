class CreateUserBookFeedbacks < ActiveRecord::Migration[8.0]
  def change
    create_table :user_book_feedbacks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :book_title
      t.string :book_author
      t.integer :feedback_type
      t.text :recommendation_context

      t.timestamps
    end
  end
end
