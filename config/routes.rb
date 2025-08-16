Rails.application.routes.draw do
  # Healthcheck minimal pour Render
  get "/health", to: proc { [200, {}, ["OK"]] }
  
  get "home/index"
  devise_for :users
  
  # Home page
  root "home#index"
  
  resources :books do
    collection do
      get :next_book   # Page de suggestion
    end
  end

  # Gestion des recommandations de lecture
  resources :recommendations, only: [:index, :create] do
    get :chat, on: :collection
    post :feedback, on: :collection
    post :refine, on: :collection

    post :chat_message, on: :collection
    post :clear_session, on: :collection
    post :cleanup_session, on: :collection
  end

  resources :imports, only: [:new, :create]
end
