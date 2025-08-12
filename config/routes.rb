Rails.application.routes.draw do
  resources :books do
    collection do
      get :next_book   # Page de suggestion
      post :feedback   # Réception du feedback
    end
  end

  # Gestion des recommandations de lecture
  resources :recommendations, only: [:new, :create] do
    post :feedback, on: :collection
  end

  # Page d'accueil par défaut
  root "books#index"
end
