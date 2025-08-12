# app/controllers/readings_controller.rb
# Rôle : afficher une liste rapide des lectures importées pour vérifier l’import.
class ReadingsController < ApplicationController
  # GET /readings
  def index
    @readings = Reading.order(date_read: :desc, date_added: :desc)

    @counts = {
      all: Reading.count,
      to_read: Reading.where(exclusive_shelf: "to-read").count,
      currently_reading: Reading.where(exclusive_shelf: "currently-reading").count,
      read: Reading.where(exclusive_shelf: "read").count
    }
  end
end
