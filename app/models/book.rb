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
end
