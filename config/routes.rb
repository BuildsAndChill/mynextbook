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

  resources :imports, only: [:new, :create]
  
  # Module d’import (upload CSV + traitement)
  resources :imports, only: [:new, :create]

  # Liste simple pour visualiser le résultat de l’import
  resources :readings, only: [:index]

  # Page d'accueil par défaut
  root "books#index"
end
