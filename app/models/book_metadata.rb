class BookMetadata < ApplicationRecord
  # Relations
  has_many :user_readings, dependent: :destroy
  has_many :users, through: :user_readings
  
  # Validations
  validates :title, :author, presence: true
  
  # Callbacks
  before_save :normalize_isbn
  
  # Scopes
  scope :with_isbn, -> { where.not(isbn: [nil, '']) }
  scope :with_isbn13, -> { where.not(isbn13: [nil, '']) }
  scope :with_goodreads_id, -> { where.not(goodreads_book_id: nil) }
  
  # Méthodes de classe
  
  # Trouve ou crée un livre basé sur l'identifiant le plus fiable disponible
  def self.find_or_create_by_identifier(attributes)
    # Priorité 1: ISBN13 (le plus fiable)
    if attributes[:isbn13].present?
      book = find_by(isbn13: attributes[:isbn13])
      return book if book
    end
    
    # Priorité 2: ISBN
    if attributes[:isbn].present?
      book = find_by(isbn: attributes[:isbn])
      return book if book
    end
    
    # Priorité 3: Goodreads ID
    if attributes[:goodreads_book_id].present?
      book = find_by(goodreads_book_id: attributes[:goodreads_book_id])
      return book if book
    end
    
    # Priorité 4: Title + Author (pour les livres sans identifiant numérique)
    if attributes[:title].present? && attributes[:author].present?
      book = find_by(title: attributes[:title], author: attributes[:author])
      return book if book
    end
    
    # Aucun livre trouvé, créer un nouveau
    create!(attributes)
  end
  
  # Trouve un livre par n'importe quel identifiant disponible
  def self.find_by_any_identifier(attributes)
    return nil if attributes.blank?
    
    # Essayer chaque identifiant dans l'ordre de priorité
    if attributes[:isbn13].present?
      book = find_by(isbn13: attributes[:isbn13])
      return book if book
    end
    
    if attributes[:isbn].present?
      book = find_by(isbn: attributes[:isbn])
      return book if book
    end
    
    if attributes[:goodreads_book_id].present?
      book = find_by(goodreads_book_id: attributes[:goodreads_book_id])
      return book if book
    end
    
    if attributes[:title].present? && attributes[:author].present?
      find_by(title: attributes[:title], author: attributes[:author])
    end
  end
  
  # Méthodes d'instance
  
  # Retourne l'identifiant le plus fiable disponible
  def primary_identifier
    isbn13 || isbn || goodreads_book_id || "#{title}-#{author}"
  end
  
  # Vérifie si ce livre a un identifiant numérique fiable
  def has_reliable_identifier?
    isbn13.present? || isbn.present?
  end
  
  # Retourne le type d'identifiant principal
  def identifier_type
    if isbn13.present?
      'ISBN13'
    elsif isbn.present?
      'ISBN'
    elsif goodreads_book_id.present?
      'Goodreads ID'
    else
      'Title + Author'
    end
  end
  
  # Retourne l'URL de couverture basée sur l'identifiant disponible
  def cover_url
    if isbn13.present?
      "https://covers.openlibrary.org/b/isbn/#{isbn13}-L.jpg"
    elsif isbn.present?
      "https://covers.openlibrary.org/b/isbn/#{isbn}-L.jpg"
    elsif goodreads_book_id.present?
      "https://images-na.ssl-images-amazon.com/images/P/#{goodreads_book_id}.01.L.jpg"
    else
      nil
    end
  end
  
  # Retourne l'URL de l'API OpenLibrary pour plus d'informations
  def api_url
    if isbn13.present?
      "https://openlibrary.org/api/books?bibkeys=ISBN:#{isbn13}&format=json&jscmd=data"
    elsif isbn.present?
      "https://openlibrary.org/api/books?bibkeys=ISBN:#{isbn}&format=json&jscmd=data"
    else
      nil
    end
  end
  
  private
  
  # Normalise les ISBN (supprime les tirets et espaces)
  def normalize_isbn
    self.isbn = isbn&.gsub(/[-\s]/, '') if isbn.present?
    self.isbn13 = isbn13&.gsub(/[-\s]/, '') if isbn13.present?
  end
end
