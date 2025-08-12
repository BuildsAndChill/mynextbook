class RestructureBooksForSharing < ActiveRecord::Migration[8.0]
  def up
    # 1. Créer une nouvelle table pour les métadonnées partagées des livres
    create_table :book_metadata do |t|
      t.string :title, null: false
      t.string :author, null: false
      t.string :isbn
      t.string :isbn13
      t.bigint :goodreads_book_id
      t.decimal :average_rating, precision: 4, scale: 2
      t.integer :pages
      t.timestamps
      
      # Index pour l'identification unique
      t.index :isbn13, unique: true, where: "isbn13 IS NOT NULL"
      t.index :isbn, unique: true, where: "isbn IS NOT NULL"
      t.index :goodreads_book_id, unique: true, where: "goodreads_book_id IS NOT NULL"
      # Index composite pour title + author (pour les livres sans ISBN)
      t.index [:title, :author], unique: true, where: "isbn IS NULL AND isbn13 IS NULL AND goodreads_book_id IS NULL"
    end

    # 2. Créer une table de liaison pour les lectures utilisateur
    create_table :user_readings do |t|
      t.bigint :user_id, null: false
      t.bigint :book_metadata_id, null: false
      t.integer :rating
      t.string :status, null: false, default: 'to_read'
      t.text :shelves
      t.date :date_added
      t.date :date_read
      t.string :exclusive_shelf
      t.timestamps
      
      # Index et contraintes
      t.index [:user_id, :book_metadata_id], unique: true
      t.index :user_id
      t.index :book_metadata_id
      t.index :status
      t.foreign_key :users
      t.foreign_key :book_metadata, column: :book_metadata_id
    end

    # 3. Migrer les données existantes
    execute <<-SQL
      -- Insérer les métadonnées des livres existants
      INSERT INTO book_metadata (title, author, isbn, isbn13, goodreads_book_id, average_rating, pages, created_at, updated_at)
      SELECT DISTINCT title, author, isbn, isbn13, goodreads_book_id, average_rating, pages, 
             MIN(created_at) as created_at, MAX(updated_at) as updated_at
      FROM books
      GROUP BY title, author, isbn, isbn13, goodreads_book_id, average_rating, pages;
    SQL

    execute <<-SQL
      -- Créer les lectures utilisateur (en évitant les doublons)
      INSERT INTO user_readings (user_id, book_metadata_id, rating, status, shelves, date_added, date_read, exclusive_shelf, created_at, updated_at)
      SELECT DISTINCT ON (b.user_id, bm.id) b.user_id, bm.id, b.rating, b.status, b.shelves, b.date_added, b.date_read, b.exclusive_shelf, b.created_at, b.updated_at
      FROM books b
      JOIN book_metadata bm ON (
        (b.isbn13 IS NOT NULL AND bm.isbn13 = b.isbn13) OR
        (b.isbn IS NOT NULL AND bm.isbn = b.isbn) OR
        (b.goodreads_book_id IS NOT NULL AND bm.goodreads_book_id = b.goodreads_book_id) OR
        (b.title = bm.title AND b.author = bm.author AND b.isbn IS NULL AND b.isbn13 IS NULL AND b.goodreads_book_id IS NULL)
      )
      ORDER BY b.user_id, bm.id, b.created_at DESC;
    SQL

    # 4. Ajouter la référence vers book_metadata (d'abord nullable)
    add_reference :books, :book_metadata, null: true, foreign_key: true
    add_index :books, [:user_id, :book_metadata_id], unique: true

    # 5. Mettre à jour les références books -> book_metadata
    execute <<-SQL
      UPDATE books SET book_metadata_id = (
        SELECT bm.id FROM book_metadata bm WHERE 
        (books.isbn13 IS NOT NULL AND bm.isbn13 = books.isbn13) OR
        (books.isbn IS NOT NULL AND bm.isbn = books.isbn) OR
        (books.goodreads_book_id IS NOT NULL AND bm.goodreads_book_id = books.goodreads_book_id) OR
        (books.title = bm.title AND books.author = bm.author AND books.isbn IS NULL AND books.isbn13 IS NULL AND books.goodreads_book_id IS NULL)
        LIMIT 1
      );
    SQL

    # 6. Maintenant rendre la colonne NOT NULL
    change_column_null :books, :book_metadata_id, false

    # 7. Supprimer les anciennes colonnes de la table books
    remove_column :books, :goodreads_book_id
    remove_column :books, :average_rating
    remove_column :books, :shelves
    remove_column :books, :date_added
    remove_column :books, :date_read
    remove_column :books, :isbn
    remove_column :books, :isbn13
    remove_column :books, :pages
    remove_column :books, :exclusive_shelf

    # 7. Supprimer la table books (remplacée par user_readings)
    drop_table :books
  end

  def down
    # Recréer la table books avec l'ancienne structure
    create_table :books do |t|
      t.string :title
      t.string :author
      t.integer :rating
      t.string :status
      t.bigint :user_id, null: false
      t.bigint :goodreads_book_id
      t.decimal :average_rating, precision: 4, scale: 2
      t.text :shelves
      t.date :date_added
      t.date :date_read
      t.string :isbn
      t.string :isbn13
      t.integer :pages
      t.string :exclusive_shelf
      t.timestamps
      
      t.index :goodreads_book_id, unique: true
      t.index :user_id
      t.foreign_key :users
    end

    # Migrer les données de user_readings vers books
    execute <<-SQL
      INSERT INTO books (title, author, rating, status, user_id, goodreads_book_id, average_rating, 
                        shelves, date_added, date_read, isbn, isbn13, pages, exclusive_shelf, created_at, updated_at)
      SELECT bm.title, bm.author, ur.rating, ur.status, ur.user_id, bm.goodreads_book_id, bm.average_rating,
             ur.shelves, ur.date_added, ur.date_read, bm.isbn, bm.isbn13, bm.pages, ur.exclusive_shelf, ur.created_at, ur.updated_at
      FROM user_readings ur
      JOIN book_metadata bm ON ur.book_metadata_id = bm.id;
    SQL

    # Supprimer les nouvelles tables
    drop_table :user_readings
    drop_table :book_metadata
  end
end
