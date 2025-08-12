class BooksController < ApplicationController
  # Action principale : affiche la bibliothèque filtrée ou complète
  def index
    # Récupère le paramètre "status" dans l'URL (?status=to_read, etc.)
    @status = params[:status]

    # Si un statut est présent → filtre, sinon affiche tout
    @books = @status.present? ? Book.by_status(@status) : Book.all
  end

  # Action : propose un livre "à lire" choisi au hasard
  def next_book
    # Sélectionne un livre à lire de manière aléatoire
    @book = Book.to_read.sample
  end

  # Action : reçoit le feedback utilisateur (like / dislike)
  def feedback
    # Ici on pourrait enregistrer en base dans un futur modèle "Feedback"
    flash[:notice] = params[:liked] == "true" ? "Bonne lecture !" : "On cherchera un autre livre."
    redirect_to next_book_books_path
  end
end
