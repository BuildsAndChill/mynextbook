class UserReading < ApplicationRecord
  # Relations
  belongs_to :user
  belongs_to :book_metadata
  
  # Déclare une énumération pour le champ 'status'
  enum :status, {
    to_read: 'to_read',
    reading: 'reading',
    read: 'read'
  }, validate: true
  
  # Validations
  validates :status, inclusion: { in: statuses.keys }
  validates :rating, numericality: { in: 1..5 }, allow_nil: true
  validates :user_id, uniqueness: { scope: :book_metadata_id, message: "a déjà ce livre dans sa bibliothèque" }
  
  # Scopes
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :for_user, ->(user) { where(user: user) if user.present? }
  scope :saved_from_recommendations, -> { where(status: 'to_read') }
  scope :imported, -> { joins(:book_metadata).where.not(book_metadata: { goodreads_book_id: nil }) }
  scope :manual, -> { joins(:book_metadata).where(book_metadata: { goodreads_book_id: nil }) }
  
  # Delegations pour accéder facilement aux métadonnées du livre
  delegate :title, :author, :isbn, :isbn13, :goodreads_book_id, :average_rating, :pages, to: :book_metadata
  delegate :cover_url, :api_url, :has_reliable_identifier?, :identifier_type, to: :book_metadata
  
  # Méthodes de classe
  
  # Vérifie si un livre existe déjà pour un utilisateur
  def self.exists_for_user?(user, book_metadata)
    where(user: user, book_metadata: book_metadata).exists?
  end
  
  # Sauvegarde un livre depuis une recommandation
  def self.save_from_recommendation(user, title, author)
    # Chercher ou créer les métadonnées du livre
    book_metadata = BookMetadata.find_or_create_by_identifier(
      title: title,
      author: author
    )
    
    # Vérifier si l'utilisateur a déjà ce livre
    existing_reading = find_by(user: user, book_metadata: book_metadata)
    
    if existing_reading
      # Mettre à jour le statut si nécessaire
      existing_reading.update(status: 'to_read') if existing_reading.status != 'to_read'
      existing_reading
    else
      # Créer une nouvelle lecture
      create!(
        user: user,
        book_metadata: book_metadata,
        status: 'to_read'
      )
    end
  end
  
  # Récupère le résumé de la liste de lecture pour un utilisateur
  def self.reading_list_summary(user)
    user_readings = where(user: user)
    
    {
      to_read: user_readings.to_read.count,
      reading: user_readings.reading.count,
      read: user_readings.read.count,
      imported: user_readings.imported.count,
      manual: user_readings.manual.count,
      total: user_readings.count
    }
  end
  
  # Méthodes d'instance
  
  # Vérifie si c'est un livre importé (depuis Goodreads)
  def imported?
    goodreads_book_id.present?
  end
  
  # Vérifie si c'est un livre ajouté manuellement
  def manual?
    goodreads_book_id.nil?
  end
  
  # Retourne le type de source pour l'affichage
  def source_type
    imported? ? 'Imported' : 'Manual'
  end
  
  # Retourne l'étagère Goodreads originale si disponible
  def original_shelf
    exclusive_shelf.presence || 'unknown'
  end
  
  # Convertit l'étagère Goodreads en statut interne
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
  
  # Retourne les attributs pour l'importation CSV
  def import_attributes
    {
      rating: rating,
      status: status,
      date_added: date_added,
      date_read: date_read,
      exclusive_shelf: exclusive_shelf,
      shelves: shelves
    }
  end
end
