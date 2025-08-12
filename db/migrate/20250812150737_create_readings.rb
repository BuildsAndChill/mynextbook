class CreateReadings < ActiveRecord::Migration[7.1]
  def change
    create_table :readings do |t|
      t.bigint   :goodreads_book_id
      t.string   :title
      t.string   :author
      t.integer  :my_rating
      t.decimal  :average_rating, precision: 4, scale: 2
      t.text     :shelves
      t.date     :date_added
      t.date     :date_read
      t.string   :isbn
      t.string   :isbn13
      t.integer  :pages

      t.timestamps
    end
  end
end
