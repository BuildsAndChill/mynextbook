class AddUniqueIndexOnReadingsGoodreadsBookId < ActiveRecord::Migration[7.1]
  def change
    add_index :readings, :goodreads_book_id, unique: true
  end
end
