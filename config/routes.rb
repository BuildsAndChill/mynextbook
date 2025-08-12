Rails.application.routes.draw do
  get "home/index"
  devise_for :users
  
  # Home page
  root "home#index"
  
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
end
