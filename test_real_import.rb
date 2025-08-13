# Test script to import the actual Goodreads CSV file
puts "=== Testing Import of Real Goodreads CSV ==="

# Find a user
user = User.first
if user.nil?
  puts "❌ No users found in database"
  exit
end

puts "✅ User found: #{user.email} (ID: #{user.id})"

# Check books before import
books_before = user.user_readings.count
puts "📚 Books before import: #{books_before}"

# Test import with the actual file
csv_file_path = "goodreads_library_export (1).csv"

if File.exist?(csv_file_path)
  puts "📄 Found CSV file: #{csv_file_path}"
  puts "📏 File size: #{File.size(csv_file_path)} bytes"
  
  # Count lines
  line_count = File.readlines(csv_file_path).count
  puts "📊 Total lines in file: #{line_count}"
  puts "📚 Expected books to import: #{line_count - 1}" # minus header
  
  begin
    puts "🔄 Starting import..."
    
    # Open file and import
    File.open(csv_file_path, 'r') do |file|
      importer = GoodreadsCsvImporter.new(file, user)
      result = importer.import
      
      puts "📊 Import result: #{result.inspect}"
      
      if result[:success]
        puts "✅ Import successful! #{result[:count]} books imported"
      else
        puts "❌ Import failed: #{result[:error]}"
      end
    end
    
  rescue => e
    puts "💥 Error during import: #{e.message}"
    puts e.backtrace.first(5).join("\n")
  end
  
  # Check books after import
  books_after = user.user_readings.count
  puts "📚 Books after import: #{books_after}"
  puts "📈 Books added: #{books_after - books_before}"
  
  # Show imported books
  imported_books = user.user_readings.joins(:book_metadata).where.not(book_metadata: { goodreads_book_id: nil })
  puts "📖 Imported books count: #{imported_books.count}"
  
  # Show some sample imported books
  puts "\n📚 Sample imported books:"
  imported_books.limit(5).each do |reading|
    puts "  - #{reading.book_metadata.title} by #{reading.book_metadata.author} (Status: #{reading.status}, Rating: #{reading.rating})"
  end
  
else
  puts "❌ CSV file not found: #{csv_file_path}"
end

puts "\n=== Test completed ==="
