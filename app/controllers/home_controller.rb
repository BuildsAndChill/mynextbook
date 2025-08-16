class HomeController < ApplicationController
  def index
    # Redirect logged-in users directly to recommendations
    if user_signed_in?
      redirect_to recommendations_path
    end
  end
end
