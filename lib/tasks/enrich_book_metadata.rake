namespace :books do
  desc "Enrich book metadata with OpenLibrary API data"
  task enrich_metadata: :environment do
    puts "Starting book metadata enrichment..."
    
    # Récupérer tous les livres avec des ISBN
    books_with_isbn = BookMetadata.where.not(isbn: [nil, '']).or(BookMetadata.where.not(isbn13: [nil, '']))
    
    puts "Found #{books_with_isbn.count} books with ISBN identifiers"
    
    enriched_count = 0
    error_count = 0
    
    books_with_isbn.find_each(batch_size: 10) do |book|
      begin
        puts "Processing: #{book.title} by #{book.author}"
        
        # Enrichir les métadonnées
        enriched_book = BookMetadataService.enrich_book_metadata(book)
        
        if enriched_book.changed?
          enriched_count += 1
          puts "  ✓ Enriched with #{enriched_book.changes.keys.join(', ')}"
        else
          puts "  - No new data available"
        end
        
        # Pause pour éviter de surcharger l'API
        sleep(0.5)
        
      rescue => e
        error_count += 1
        puts "  ✗ Error: #{e.message}"
      end
    end
    
    puts "\nEnrichment completed!"
    puts "Books enriched: #{enriched_count}"
    puts "Errors: #{error_count}"
  end
  
  desc "Search for books by query and display results"
  task :search, [:query] => :environment do |task, args|
    query = args[:query]
    
    if query.blank?
      puts "Usage: rake books:search[query]"
      puts "Example: rake books:search['Harry Potter']"
      exit
    end
    
    puts "Searching for: #{query}"
    results = BookMetadataService.search_books(query, 5)
    
    if results.any?
      puts "\nFound #{results.count} books:"
      results.each_with_index do |book, i|
        puts "\n#{i + 1}. #{book[:title]}"
        puts "   Author: #{book[:author]}"
        puts "   ISBN: #{book[:isbn] || 'N/A'}"
        puts "   ISBN13: #{book[:isbn13] || 'N/A'}"
        puts "   Pages: #{book[:pages] || 'N/A'}"
        puts "   Cover: #{book[:cover_url] || 'N/A'}"
      end
    else
      puts "No books found."
    end
  end
  
  desc "Get cover URLs for a specific ISBN"
  task :covers, [:isbn] => :environment do |task, args|
    isbn = args[:isbn]
    
    if isbn.blank?
      puts "Usage: rake books:covers[isbn]"
      puts "Example: rake books:covers[9780747532699]"
      exit
    end
    
    puts "Getting cover URLs for ISBN: #{isbn}"
    cover_urls = BookMetadataService.get_cover_urls(isbn)
    
    if cover_urls.any?
      puts "\nAvailable cover URLs:"
      cover_urls.each_with_index do |url, i|
        size = ['S', 'M', 'L'][i]
        puts "#{size}: #{url}"
      end
    else
      puts "No cover URLs found."
    end
  end
  
  desc "Show statistics about book identifiers"
  task stats: :environment do
    total_books = BookMetadata.count
    books_with_isbn13 = BookMetadata.where.not(isbn13: [nil, '']).count
    books_with_isbn = BookMetadata.where.not(isbn: [nil, '']).count
    books_with_goodreads = BookMetadata.where.not(goodreads_book_id: [nil, '']).count
    books_without_identifier = BookMetadata.where(isbn: [nil, ''], isbn13: [nil, ''], goodreads_book_id: nil).count
    
    puts "Book Metadata Statistics:"
    puts "========================"
    puts "Total books: #{total_books}"
    puts "With ISBN13: #{books_with_isbn13} (#{(books_with_isbn13.to_f / total_books * 100).round(1)}%)"
    puts "With ISBN: #{books_with_isbn} (#{(books_with_isbn.to_f / total_books * 100).round(1)}%)"
    puts "With Goodreads ID: #{books_with_goodreads} (#{(books_with_goodreads.to_f / total_books * 100).round(1)}%)"
    puts "Without reliable identifier: #{books_without_identifier} (#{(books_without_identifier.to_f / total_books * 100).round(1)}%)"
    
    puts "\nIdentifier Quality:"
    puts "=================="
    if books_with_isbn13 > 0
      puts "✓ #{books_with_isbn13} books have ISBN13 (most reliable)"
    end
    if books_with_isbn > 0
      puts "✓ #{books_with_isbn} books have ISBN"
    end
    if books_with_goodreads > 0
      puts "✓ #{books_with_goodreads} books have Goodreads ID"
    end
    if books_without_identifier > 0
      puts "⚠ #{books_without_identifier} books rely on title+author only"
    end
  end
end
