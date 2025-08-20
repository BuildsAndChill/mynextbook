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
      delete :clear_library  # Vider toute la librairie
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

  # Admin routes
  get 'admin/dashboard', to: 'admin#dashboard'
  post 'admin/dashboard', to: 'admin#dashboard'  # Pour l'authentification
  delete 'admin/logout', to: 'admin#logout'      # Pour la déconnexion
  get 'admin/logs', to: 'admin#logs'
  get 'admin/sessions', to: 'admin#sessions'
  get 'admin/interactions', to: 'admin#interactions'
  get 'admin/subscribers', to: 'admin#subscribers'
  get 'admin/users', to: 'admin#users'
  get 'admin/analytics', to: 'admin#analytics'
  get 'admin/export_data', to: 'admin#export_data'
  
  # User tracking routes (redirigé vers sessions)
  namespace :admin do
    get 'tracking', to: redirect('/admin/sessions')
    get 'tracking/analytics', to: redirect('/admin/sessions')
    get 'refresh_analytics', to: 'admin#refresh_analytics'
  end

  resources :imports, only: [:new, :create]
  
  # Capture des emails pour recommandations
  resources :subscribers, only: [:create]
  get 'unsubscribe', to: 'subscribers#unsubscribe'
end
