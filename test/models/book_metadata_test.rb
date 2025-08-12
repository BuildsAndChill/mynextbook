require "test_helper"

class BookMetadataTest < ActiveSupport::TestCase
  def setup
    @book_attrs = {
      title: "Test Book",
      author: "Test Author",
      isbn: "1234567890",
      isbn13: "9781234567890",
      goodreads_book_id: 12345,
      pages: 300,
      average_rating: 4.5
    }
  end

  test "should create book metadata with valid attributes" do
    book = BookMetadata.new(@book_attrs)
    assert book.save
  end

  test "should require title and author" do
    book = BookMetadata.new(@book_attrs.except(:title))
    assert_not book.save
    
    book = BookMetadata.new(@book_attrs.except(:author))
    assert_not book.save
  end

  test "should normalize ISBN by removing dashes and spaces" do
    book = BookMetadata.create!(
      @book_attrs.merge(
        isbn: "123-456-789-0",
        isbn13: "978-123-456-789-0"
      )
    )
    
    assert_equal "1234567890", book.isbn
    assert_equal "9781234567890", book.isbn13
  end

  test "should find book by ISBN13" do
    book = BookMetadata.create!(@book_attrs)
    found = BookMetadata.find_by_any_identifier(isbn13: "9781234567890")
    assert_equal book, found
  end

  test "should find book by ISBN" do
    book = BookMetadata.create!(@book_attrs)
    found = BookMetadata.find_by_any_identifier(isbn: "1234567890")
    assert_equal book, found
  end

  test "should find book by Goodreads ID" do
    book = BookMetadata.create!(@book_attrs)
    found = BookMetadata.find_by_any_identifier(goodreads_book_id: 12345)
    assert_equal book, found
  end

  test "should find book by title and author when no identifiers" do
    book = BookMetadata.create!(@book_attrs.except(:isbn, :isbn13, :goodreads_book_id))
    found = BookMetadata.find_by_any_identifier(
      title: "Test Book",
      author: "Test Author"
    )
    assert_equal book, found
  end

  test "should create new book when none found" do
    assert_difference 'BookMetadata.count' do
      book = BookMetadata.find_or_create_by_identifier(@book_attrs)
      assert book.persisted?
    end
  end

  test "should return existing book when found" do
    existing_book = BookMetadata.create!(@book_attrs)
    
    assert_no_difference 'BookMetadata.count' do
      found_book = BookMetadata.find_or_create_by_identifier(@book_attrs)
      assert_equal existing_book, found_book
    end
  end

  test "should prioritize ISBN13 over ISBN" do
    # Créer un livre avec ISBN
    book_with_isbn = BookMetadata.create!(@book_attrs.except(:isbn13))
    
    # Chercher avec ISBN13 (qui devrait créer un nouveau livre)
    search_attrs = @book_attrs.merge(isbn: book_with_isbn.isbn)
    found_book = BookMetadata.find_or_create_by_identifier(search_attrs)
    
    # Le livre trouvé devrait être différent car l'ISBN13 a la priorité
    assert_not_equal book_with_isbn, found_book
  end

  test "should return primary identifier" do
    book = BookMetadata.create!(@book_attrs)
    assert_equal "9781234567890", book.primary_identifier
    
    book_without_isbn13 = BookMetadata.create!(@book_attrs.except(:isbn13))
    assert_equal "1234567890", book_without_isbn13.primary_identifier
    
    book_without_isbn = BookMetadata.create!(@book_attrs.except(:isbn, :isbn13))
    assert_equal "12345", book_without_isbn.primary_identifier
    
    book_without_identifiers = BookMetadata.create!(@book_attrs.except(:isbn, :isbn13, :goodreads_book_id))
    assert_equal "Test Book-Test Author", book_without_identifiers.primary_identifier
  end

  test "should check if has reliable identifier" do
    book_with_isbn13 = BookMetadata.create!(@book_attrs)
    assert book_with_isbn13.has_reliable_identifier?
    
    book_without_isbn = BookMetadata.create!(@book_attrs.except(:isbn, :isbn13))
    assert_not book_without_isbn.has_reliable_identifier?
  end

  test "should return identifier type" do
    book_with_isbn13 = BookMetadata.create!(@book_attrs)
    assert_equal "ISBN13", book_with_isbn13.identifier_type
    
    book_with_isbn = BookMetadata.create!(@book_attrs.except(:isbn13))
    assert_equal "ISBN", book_with_isbn.identifier_type
    
    book_with_goodreads = BookMetadata.create!(@book_attrs.except(:isbn, :isbn13))
    assert_equal "Goodreads ID", book_with_goodreads.identifier_type
    
    book_without_identifiers = BookMetadata.create!(@book_attrs.except(:isbn, :isbn13, :goodreads_book_id))
    assert_equal "Title + Author", book_without_identifiers.identifier_type
  end

  test "should return cover URL for ISBN13" do
    book = BookMetadata.create!(@book_attrs)
    expected_url = "https://covers.openlibrary.org/b/isbn/9781234567890-L.jpg"
    assert_equal expected_url, book.cover_url
  end

  test "should return cover URL for ISBN" do
    book = BookMetadata.create!(@book_attrs.except(:isbn13))
    expected_url = "https://covers.openlibrary.org/b/isbn/1234567890-L.jpg"
    assert_equal expected_url, book.cover_url
  end

  test "should return cover URL for Goodreads ID" do
    book = BookMetadata.create!(@book_attrs.except(:isbn, :isbn13))
    expected_url = "https://images-na.ssl-images-amazon.com/images/P/12345.01.L.jpg"
    assert_equal expected_url, book.cover_url
  end

  test "should return nil cover URL when no identifiers" do
    book = BookMetadata.create!(@book_attrs.except(:isbn, :isbn13, :goodreads_book_id))
    assert_nil book.cover_url
  end

  test "should return API URL for ISBN13" do
    book = BookMetadata.create!(@book_attrs)
    expected_url = "https://openlibrary.org/api/books?bibkeys=ISBN:9781234567890&format=json&jscmd=data"
    assert_equal expected_url, book.api_url
  end

  test "should return API URL for ISBN" do
    book = BookMetadata.create!(@book_attrs.except(:isbn13))
    expected_url = "https://openlibrary.org/api/books?bibkeys=ISBN:1234567890&format=json&jscmd=data"
    assert_equal expected_url, book.api_url
  end

  test "should return nil API URL when no ISBN" do
    book = BookMetadata.create!(@book_attrs.except(:isbn, :isbn13))
    assert_nil book.api_url
  end

  test "should have unique ISBN13 constraint" do
    BookMetadata.create!(@book_attrs)
    
    duplicate_book = BookMetadata.new(@book_attrs.merge(title: "Different Title"))
    assert_not duplicate_book.save
    assert_includes duplicate_book.errors[:isbn13], "has already been taken"
  end

  test "should have unique ISBN constraint" do
    BookMetadata.create!(@book_attrs.except(:isbn13))
    
    duplicate_book = BookMetadata.new(@book_attrs.except(:isbn13).merge(title: "Different Title"))
    assert_not duplicate_book.save
    assert_includes duplicate_book.errors[:isbn], "has already been taken"
  end

  test "should have unique Goodreads ID constraint" do
    BookMetadata.create!(@book_attrs.except(:isbn, :isbn13))
    
    duplicate_book = BookMetadata.new(@book_attrs.except(:isbn, :isbn13).merge(title: "Different Title"))
    assert_not duplicate_book.save
    assert_includes duplicate_book.errors[:goodreads_book_id], "has already been taken"
  end

  test "should have unique title+author constraint when no identifiers" do
    BookMetadata.create!(@book_attrs.except(:isbn, :isbn13, :goodreads_book_id))
    
    duplicate_book = BookMetadata.new(@book_attrs.except(:isbn, :isbn13, :goodreads_book_id))
    assert_not duplicate_book.save
    assert_includes duplicate_book.errors[:title], "has already been taken"
  end
end
