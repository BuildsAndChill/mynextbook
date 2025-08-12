class ConsolidateBooksAndReadings < ActiveRecord::Migration[8.0]
  def up
    # Add missing columns to books table to match readings functionality
    add_column :books, :goodreads_book_id, :bigint
    add_column :books, :average_rating, :decimal, precision: 4, scale: 2
    add_column :books, :shelves, :text
    add_column :books, :date_added, :date
    add_column :books, :date_read, :date
    add_column :books, :isbn, :string
    add_column :books, :isbn13, :string
    add_column :books, :pages, :integer
    add_column :books, :exclusive_shelf, :string
    
    # Add index for goodreads_book_id
    add_index :books, :goodreads_book_id, unique: true
    
    # Migrate data from readings to books
    execute <<-SQL
      INSERT INTO books (title, author, rating, status, goodreads_book_id, average_rating, 
                        shelves, date_added, date_read, isbn, isbn13, pages, exclusive_shelf, 
                        user_id, created_at, updated_at)
      SELECT title, author, my_rating as rating, 
             CASE 
               WHEN exclusive_shelf = 'read' THEN 'read'
               WHEN exclusive_shelf = 'currently-reading' THEN 'reading'
               WHEN exclusive_shelf = 'to-read' THEN 'to_read'
               ELSE 'to_read'
             END as status,
             goodreads_book_id, average_rating, shelves, date_added, date_read, 
             isbn, isbn13, pages, exclusive_shelf, user_id, created_at, updated_at
      FROM readings
      ON CONFLICT (goodreads_book_id) DO NOTHING;
    SQL
    
    # Drop the readings table
    drop_table :readings
  end

  def down
    # Recreate readings table
    create_table :readings do |t|
      t.bigint :goodreads_book_id
      t.string :title
      t.string :author
      t.integer :my_rating
      t.decimal :average_rating, precision: 4, scale: 2
      t.text :shelves
      t.date :date_added
      t.date :date_read
      t.string :isbn
      t.string :isbn13
      t.integer :pages
      t.string :exclusive_shelf
      t.bigint :user_id, null: false
      t.timestamps
    end
    
    add_index :readings, :goodreads_book_id, unique: true
    add_index :readings, :user_id
    add_foreign_key :readings, :users
    
    # Remove added columns from books
    remove_column :books, :goodreads_book_id
    remove_column :books, :average_rating
    remove_column :books, :shelves
    remove_column :books, :date_added
    remove_column :books, :date_read
    remove_column :books, :isbn
    remove_column :books, :isbn13
    remove_column :books, :pages
    remove_column :books, :exclusive_shelf
  end
end
