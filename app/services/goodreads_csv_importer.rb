# app/services/goodreads_csv_importer.rb
# Service objet responsable de :
# - Lire le CSV Goodreads (headers officiels)
# - Mapper chaque ligne vers nos attributs Book
# - Créer / mettre à jour en idempotent (find_or_initialize_by :goodreads_book_id)
# - Retourner un petit résumé (créés / MAJ / ignorés / erreurs)
#
# Usage (dans un contrôleur) :
#   result = GoodreadsCsvImporter.new(file.tempfile).call
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

    # Goodreads exporte un CSV avec headers. En général UTF-8 (parfois avec BOM).
    csv = CSV.new(@io, headers: true, return_headers: false)

    csv.each_with_index do |row, i|
      begin
        # 1) Transformer la ligne CSV en hash d'attributs pour Book
        attrs = map_row(row)

        # 2) Filtrage minimal : si pas d'ID ou pas de titre → on ignore
        if attrs[:goodreads_book_id].nil? || attrs[:title].blank?
          skipped += 1
          next
        end

        # 3) Idempotence sur goodreads_book_id
        rec = Book.find_or_initialize_by(goodreads_book_id: attrs[:goodreads_book_id])

        if rec.new_record?
          # Nouveau : assigner tous les attributs puis save!
          rec.assign_attributes(attrs)
          rec.user = @user if @user
          rec.save!
          created += 1
        else
          # Existant : ne sauvegarder que s'il y a des changements
          rec.assign_attributes(attrs)
          if rec.changed?
            rec.save!
            updated += 1
          else
            # Aucune diff → on compte comme ignoré (ça permet de rassurer sur l'idempotence)
            skipped += 1
          end
        end

      rescue => e
        # On stocke max d'info utile pour debug (numéro de ligne visible par l'utilisateur)
        # i + 2 = on ajoute 2 car i commence à 0 et la ligne 1 = headers
        errors << "Ligne #{i + 2}: #{e.message}"
      end
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
    status = Book.convert_goodreads_shelf(exclusive)
    
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
      shelves:           [exclusive, extra_shelves.presence].compact.join(", ")
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
    Integer(s) rescue nil
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
