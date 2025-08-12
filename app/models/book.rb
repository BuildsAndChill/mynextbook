class Book < ApplicationRecord
  belongs_to :user
  
  # Déclare une énumération pour le champ 'status'
  # Les clés ('to_read', 'reading', 'read') seront disponibles comme méthodes
  enum :status, {
    to_read: 'to_read',
    reading: 'reading',
    read: 'read'
  }, validate: true

  # Validation : titre et auteur doivent être présents
  validates :title, :author, presence: true

  # Validation : la note doit être entre 1 et 5, mais peut être vide (allow_nil)
  validates :rating, numericality: { in: 1..5 }, allow_nil: true

  # Validation : le status doit être l'une des clés définies dans l'enum ci-dessus
  validates :status, inclusion: { in: statuses.keys }

  # Scope : filtre les livres par status si un paramètre est fourni
  # Exemple : Book.by_status("read") → retourne uniquement les livres lus
  scope :by_status, ->(status) { where(status: status) if status.present? }
  
  # Scope : filtre les livres par utilisateur
  scope :for_user, ->(user) { where(user: user) if user.present? }
  
  # Scope for books saved from recommendations
  scope :saved_from_recommendations, -> { where(status: 'to_read') }
  
  # Scope for imported books (from Goodreads)
  scope :imported, -> { where.not(goodreads_book_id: nil) }
  
  # Scope for manually added books
  scope :manual, -> { where(goodreads_book_id: nil) }
  
  # Check if book already exists for user
  def self.exists_for_user?(user, title, author)
    user.books.where(title: title, author: author).exists?
  end
  
  # Save book from recommendation to user's reading list
  def self.save_from_recommendation(user, title, author)
    # Check if book already exists
    existing_book = user.books.find_by(title: title, author: author)
    
    if existing_book
      # Update status to to_read if it was different
      existing_book.update(status: 'to_read') if existing_book.status != 'to_read'
      existing_book
    else
      # Create new book
      create!(
        user: user,
        title: title,
        author: author,
        status: 'to_read'
      )
    end
  end
  
  # Get reading list summary for user
  def self.reading_list_summary(user)
    {
      to_read: user.books.to_read.count,
      reading: user.books.reading.count,
      read: user.books.read.count,
      imported: user.books.imported.count,
      manual: user.books.manual.count,
      total: user.books.count
    }
  end
  
  # Check if this is an imported book (from Goodreads)
  def imported?
    goodreads_book_id.present?
  end
  
  # Check if this is a manually added book
  def manual?
    goodreads_book_id.nil?
  end
  
  # Get the source type for display
  def source_type
    imported? ? 'Imported' : 'Manual'
  end
  
  # Get the original Goodreads shelf if available
  def original_shelf
    exclusive_shelf.presence || 'unknown'
  end
  
  # Convert Goodreads shelf to internal status
  def self.convert_goodreads_shelf(shelf)
    case shelf&.downcase
    when 'read'
      'read'
    when 'currently-reading'
      'reading'
    when 'to-read'
      'to_read'
    else
      'to_read'
    end
  end
end
