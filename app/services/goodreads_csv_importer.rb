# app/services/goodreads_csv_importer.rb
# Service objet responsable de :
# - Lire le CSV Goodreads (headers officiels)
# - Mapper chaque ligne vers nos attributs Book
# - Créer / mettre à jour en idempotent (find_or_initialize_by :goodreads_book_id + user_id)
# - Retourner un petit résumé (créés / MAJ / ignorés / erreurs)
#
# Usage (dans un contrôleur) :
#   result = GoodreadsCsvImporter.new(file.tempfile, user).call
#   result.created, result.updated, result.skipped, result.errors
#
require "csv"

class GoodreadsCsvImporter
  # Struct légère pour un retour propre
  Result = Struct.new(:created, :updated, :skipped, :errors, keyword_init: true)

  def initialize(io, user = nil)
    # io = un IO-like (ex: file.tempfile) ; on ne lit pas tout en mémoire
    @io = io
    @user = user
  end

  def call
    created = 0
    updated = 0
    skipped = 0
    errors  = []

    # Récupérer la limite d'import depuis la configuration
    import_limit = ENV.fetch('IMPORT_BOOKS_LIMIT', '0').to_i
    
    Rails.logger.info "Starting CSV import for user: #{@user&.id}"
    if import_limit > 0
      Rails.logger.info "Import limit set to #{import_limit} books (for testing)"
    end

    # Goodreads exporte un CSV avec headers. En général UTF-8 (parfois avec BOM).
    csv = CSV.new(@io, headers: true, return_headers: false)

    csv.each_with_index do |row, i|
      # Vérifier la limite d'import - compter TOUS les livres traités
      total_processed = created + updated + skipped
      if import_limit > 0 && total_processed >= import_limit
        Rails.logger.info "Import limit reached (#{import_limit} books processed). Stopping import."
        break
      end
      
      begin
        # 1) Transformer la ligne CSV en hash d'attributs pour Book
        attrs = map_row(row)
        
        Rails.logger.info "Processing row #{i + 2}: #{attrs[:title]} by #{attrs[:author]}"

        # 2) Filtrage minimal : si pas d'ID ou pas de titre → on ignore
        if attrs[:goodreads_book_id].nil? || attrs[:title].blank?
          Rails.logger.info "Skipping row #{i + 2}: missing goodreads_book_id or title"
          skipped += 1
          next
        end

        # 3) Idempotence basée sur l'identifiant le plus fiable
        # Séparer les attributs pour BookMetadata et UserReading
        book_metadata_attrs = attrs.slice(:title, :author, :isbn, :isbn13, :goodreads_book_id, :average_rating, :pages)
        book_metadata = BookMetadata.find_or_create_by_identifier(book_metadata_attrs)
        
        # 4) Vérifier si l'utilisateur a déjà ce livre
        existing_reading = UserReading.find_by(user: @user, book_metadata: book_metadata)
        
        if existing_reading.nil?
          # Nouvelle lecture pour cet utilisateur
          reading = UserReading.new(
            user: @user,
            book_metadata: book_metadata,
            rating: attrs[:rating],
            status: attrs[:status],
            shelves: attrs[:shelves],
            date_added: attrs[:date_added],
            date_read: attrs[:date_read],
            exclusive_shelf: attrs[:exclusive_shelf]
          )
          reading.save!
          Rails.logger.info "Created new reading for user: #{reading.book_metadata.title} (ID: #{reading.id})"
          created += 1
        else
          # Lecture existante : mettre à jour si nécessaire
          old_attrs = existing_reading.import_attributes
          new_attrs = attrs.except(:title, :author, :isbn, :isbn13, :goodreads_book_id, :average_rating, :pages)
          
          if old_attrs.except(:title, :author, :isbn, :isbn13, :goodreads_book_id, :average_rating, :pages) != new_attrs
            existing_reading.update!(new_attrs)
            Rails.logger.info "Updated existing reading: #{existing_reading.book_metadata.title} (ID: #{existing_reading.id})"
            updated += 1
          else
            # Aucune diff → on compte comme ignoré
            Rails.logger.info "No changes for existing reading: #{existing_reading.book_metadata.title}"
            skipped += 1
          end
        end

      rescue => e
        # On stocke max d'info utile pour debug (numéro de ligne visible par l'utilisateur)
        # i + 2 = on ajoute 2 car i commence à 0 et la ligne 1 = headers
        error_msg = "Ligne #{i + 2}: #{e.message}"
        Rails.logger.error error_msg
        errors << error_msg
      end
    end

    # Message final avec information sur la limite
    total_processed = created + updated + skipped
    if import_limit > 0 && total_processed >= import_limit
      Rails.logger.info "CSV import stopped at limit: #{total_processed} books processed (limit: #{import_limit}) - #{created} created, #{updated} updated, #{skipped} skipped, #{errors.length} errors"
    else
      Rails.logger.info "CSV import completed: #{created} created, #{updated} updated, #{skipped} skipped, #{errors.length} errors"
    end
    
    Result.new(created:, updated:, skipped:, errors:)
  end

  def import
    result = call
    if result.errors.any?
      { success: false, error: result.errors.join(", ") }
    else
      { success: true, count: result.created + result.updated }
    end
  end

  private

  # --- Helpers de mapping & parsing ---

  # Mappe les entêtes Goodreads → nos colonnes Book
  # Entêtes possibles (selon exports) :
  # "Book Id","Title","Author","My Rating","Average Rating","Number of Pages",
  # "Date Added","Date Read","ISBN","ISBN13","Bookshelves" (ou "Shelves")
  def map_row(row)
    exclusive = safe_s(row["Exclusive Shelf"])
    extra_shelves = safe_s(row["Bookshelves"] || row["Shelves"])
    
    # Convert Goodreads shelf to internal status
    status = UserReading.convert_goodreads_shelf(exclusive)
    
    {
      goodreads_book_id: to_i_or_nil(row["Book Id"]),
      title:             safe_s(row["Title"]),
      author:            safe_s(row["Author"]),
      rating:            to_i_or_nil(row["My Rating"]),
      status:            status,
      average_rating:    to_d_or_nil(row["Average Rating"]),
      pages:             to_i_or_nil(row["Number of Pages"]),
      date_added:        to_date_or_nil(row["Date Added"]),
      date_read:         to_date_or_nil(row["Date Read"]),
      isbn:              safe_s(row["ISBN"]),
      isbn13:            safe_s(row["ISBN13"]),
      exclusive_shelf:   exclusive,
      shelves:           [exclusive, extra_shelves.presence].compact.join(", "),
      user_id:           @user&.id
    }
  end

  # Normalise une chaîne : strip si string, sinon renvoie tel quel (nil reste nil)
  def safe_s(v)
    v.is_a?(String) ? v.strip : v
  end

  # Convertit en Integer, sinon nil
  def to_i_or_nil(v)
    s = safe_s(v)
    return nil if s.blank?
    rating = Integer(s) rescue nil
    # Goodreads uses 0 to mean "no rating", convert to nil
    rating == 0 ? nil : rating
  end

  # Convertit en BigDecimal, sinon nil
  def to_d_or_nil(v)
    s = safe_s(v)
    return nil if s.blank?
    BigDecimal(s) rescue nil
  end

  # Convertit en Date (via Date.parse), sinon nil
  def to_date_or_nil(v)
    s = safe_s(v)
    return nil if s.blank?
    Date.parse(s) rescue nil
  end
end
