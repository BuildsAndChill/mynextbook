# app/controllers/readings_controller.rb
# Rôle : afficher une liste rapide des lectures importées pour vérifier l’import.
class ReadingsController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @readings = Reading.all
  end
end
