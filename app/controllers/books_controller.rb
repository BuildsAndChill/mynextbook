class BooksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_book, only: [:show, :edit, :update, :destroy]

  # Action principale : affiche la bibliothèque filtrée ou complète
  def index
    # Récupère le paramètre "status" dans l'URL (?status=to_read, etc.)
    @status = params[:status]
    @show_imported = params[:imported] == 'true'

    # Si un statut est présent → filtre, sinon affiche tout
    @books = current_user.user_readings.includes(:book_metadata)
    
    if @show_imported
      # Show only imported books (from Goodreads)
      @books = @books.joins(:book_metadata).where.not(book_metadata: { goodreads_book_id: nil })
      @imported_count = @books.count
    elsif @status.present?
      @books = @books.by_status(@status)
    end
    
    # Get library summary
    @library_summary = UserReading.reading_list_summary(current_user)
    
    # Enrich books with Goodreads data (temporary, no persistence)
    enrich_library_with_goodreads_data(@books)
  end

  def show
  end

  def new
    @book = current_user.user_readings.build
  end

  def edit
  end

  def create
    # Créer ou trouver les métadonnées du livre
    book_metadata = BookMetadata.find_or_create_by_identifier(
      title: book_params[:title],
      author: book_params[:author],
      isbn: book_params[:isbn],
      isbn13: book_params[:isbn13],
      goodreads_book_id: book_params[:goodreads_book_id],
      average_rating: book_params[:average_rating],
      pages: book_params[:pages]
    )
    
    @book = current_user.user_readings.build(
      book_metadata: book_metadata,
      rating: book_params[:rating],
      status: book_params[:status],
      shelves: book_params[:shelves],
      date_added: book_params[:date_added],
      date_read: book_params[:date_read],
      exclusive_shelf: book_params[:exclusive_shelf]
    )

    if @book.save
      redirect_to @book, notice: 'Book was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    # Mettre à jour les métadonnées du livre si nécessaire
    if book_params[:title].present? || book_params[:author].present?
      @book.book_metadata.update!(
        title: book_params[:title] || @book.book_metadata.title,
        author: book_params[:author] || @book.book_metadata.author,
        isbn: book_params[:isbn] || @book.book_metadata.isbn,
        isbn13: book_params[:isbn13] || @book.book_metadata.isbn13,
        goodreads_book_id: book_params[:goodreads_book_id] || @book.book_metadata.goodreads_book_id,
        average_rating: book_params[:average_rating] || @book.book_metadata.average_rating,
        pages: book_params[:pages] || @book.book_metadata.pages
      )
    end
    
    # Mettre à jour les attributs de lecture
    reading_params = book_params.except(:title, :author, :isbn, :isbn13, :goodreads_book_id, :average_rating, :pages)
    
    if @book.update(reading_params)
      redirect_to @book, notice: 'Book was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @book.destroy
    redirect_to books_url, notice: 'Book was successfully deleted.'
  end

  # Action : propose un livre "à lire" choisi au hasard
  def next_book
    # Sélectionne un livre à lire de manière aléatoire
    @book = current_user.user_readings.to_read.includes(:book_metadata).sample
  end

  # Action : reçoit le feedback utilisateur (like / dislike)
  def feedback
    # Ici on pourrait enregistrer en base dans un futur modèle "Feedback"
    flash[:notice] = params[:liked] == "true" ? "Bonne lecture !" : "On cherchera un autre livre."
    redirect_to next_book_books_path
  end

  # Action : vider toute la librairie de l'utilisateur
  def clear_library
    begin
      # Supprimer toutes les lectures de l'utilisateur
      deleted_count = current_user.user_readings.count
      current_user.user_readings.destroy_all
      
      # Optionnel : supprimer les métadonnées de livres qui ne sont plus utilisées
      # (seulement si elles n'appartiennent à aucun autre utilisateur)
      orphaned_metadata = BookMetadata.left_joins(:user_readings)
                                     .where(user_readings: { id: nil })
      orphaned_count = orphaned_metadata.count
      orphaned_metadata.destroy_all
      
      render json: {
        success: true,
        message: "Library cleared successfully",
        deleted_books: deleted_count,
        deleted_metadata: orphaned_count
      }
    rescue => e
      Rails.logger.error "Error clearing library: #{e.message}"
      render json: {
        success: false,
        error: "Failed to clear library: #{e.message}"
      }, status: :internal_server_error
    end
  end

  private

  # Enrich library books with Goodreads data (temporary, no persistence)
  def enrich_library_with_goodreads_data(books)
    return unless books.any?
    
    Rails.logger.info "Enriching library books with Goodreads data (temporary)"
    
    # Enrich each book temporarily with Goodreads data
    books.each do |book|
      begin
        # Add Goodreads data as instance variables (temporary)
        if book.book_metadata&.goodreads_book_id.present?
          # Goodreads cover URL (if available)
          book.instance_variable_set(:@goodreads_cover_url, "https://images-na.ssl-images-amazon.com/images/P/#{book.book_metadata.goodreads_book_id}.L.jpg")
          
          # Goodreads rating (from average_rating)
          if book.book_metadata.average_rating.present?
            book.instance_variable_set(:@goodreads_rating, book.book_metadata.average_rating)
          end
          
          # Goodreads link
          book.instance_variable_set(:@goodreads_link, "https://www.goodreads.com/book/show/#{book.book_metadata.goodreads_book_id}")
          
          Rails.logger.info "Temporarily enriched library book '#{book.book_metadata.title}' with Goodreads data"
        end
      rescue => e
        Rails.logger.error "Failed to enrich Goodreads data for library book '#{book.book_metadata.title}': #{e.message}"
        # Continue without enrichment - don't block the library display
      end
    end
    
    Rails.logger.info "Goodreads enrichment completed for library"
  end

  def set_book
    @book = current_user.user_readings.includes(:book_metadata).find(params[:id])
  end

  def book_params
    params.require(:book).permit(:title, :author, :rating, :status, :goodreads_book_id, 
                                :average_rating, :shelves, :date_added, :date_read, 
                                :isbn, :isbn13, :pages, :exclusive_shelf)
  end
end
