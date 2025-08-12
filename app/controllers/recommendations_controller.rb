class RecommendationsController < ApplicationController
  # Page de saisie du contexte utilisateur
  def new
    # Rien à préparer ici, on affiche juste le formulaire (views/recommendations/new.html.erb)
  end

  # Réception du formulaire et construction du prompt dynamique
  def create
    user_context = params[:context].to_s

    read_books = Book.read.pluck(:title, :author).map { |t, a| "#{t} – #{a}" }.join("\n")
    to_read_books = Book.to_read.pluck(:title, :author).map { |t, a| "#{t} – #{a}" }.join("\n")

    @user_prompt = <<~PROMPT
      Contexte utilisateur :
      #{user_context.presence || "(non fourni)"}

      Livres déjà lus :
      #{read_books.presence || "(aucun)"}

      Livres à lire :
      #{to_read_books.presence || "(aucun)"}
    PROMPT
    
    result = BookRecommender.new(user_prompt: @user_prompt).call
    @recommendations = result[:items]
    @ai_raw = result[:raw]
    @ai_error = result[:error]

    render :create, status: :ok
  end

  # Gestion du feedback utilisateur (Yes / No)
  def feedback
    # Ici on pourra stocker le feedback et relancer une nouvelle proposition
    flash[:notice] = params[:liked] == "true" ? "Bonne lecture !" : "On cherchera un autre livre."
    redirect_to new_recommendation_path
  end
end
