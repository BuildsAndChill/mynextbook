require "test_helper"

class BookMetadataTest < ActiveSupport::TestCase
  test "should create book metadata with valid attributes" do
    book = BookMetadata.new(
      title: "Test Book",
      author: "Test Author",
      isbn: "1234567890"
    )
    assert book.save
  end

  test "should require title and author" do
    book = BookMetadata.new(isbn: "1234567890")
    assert_not book.save
    assert_includes book.errors[:title], "can't be blank"
    assert_includes book.errors[:author], "can't be blank"
  end
end
