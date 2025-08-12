class BooksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_book, only: [:show, :edit, :update, :destroy]

  # Action principale : affiche la bibliothèque filtrée ou complète
  def index
    # Récupère le paramètre "status" dans l'URL (?status=to_read, etc.)
    @status = params[:status]

    # Si un statut est présent → filtre, sinon affiche tout
    @books = current_user.books
    @books = @books.by_status(@status) if @status.present?
    
    # Get library summary
    @library_summary = {
      to_read: current_user.books.to_read.count,
      reading: current_user.books.reading.count,
      read: current_user.books.read.count,
      imported: current_user.books.imported.count,
      manual: current_user.books.manual.count,
      total: current_user.books.count
    }
  end

  def show
  end

  def new
    @book = current_user.books.build
  end

  def edit
  end

  def create
    @book = current_user.books.build(book_params)

    if @book.save
      redirect_to @book, notice: 'Book was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @book.update(book_params)
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
    @book = current_user.books.to_read.sample
  end

  # Action : reçoit le feedback utilisateur (like / dislike)
  def feedback
    # Ici on pourrait enregistrer en base dans un futur modèle "Feedback"
    flash[:notice] = params[:liked] == "true" ? "Bonne lecture !" : "On cherchera un autre livre."
    redirect_to next_book_books_path
  end

  private

  def set_book
    @book = current_user.books.find(params[:id])
  end

  def book_params
    params.require(:book).permit(:title, :author, :rating, :status, :goodreads_book_id, 
                                :average_rating, :shelves, :date_added, :date_read, 
                                :isbn, :isbn13, :pages, :exclusive_shelf)
  end
end
