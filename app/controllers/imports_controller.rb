# app/controllers/imports_controller.rb
# Rôle : afficher le formulaire d’upload + traiter l’import CSV via le service.
class ImportsController < ApplicationController
  before_action :authenticate_user!
  
  def new
  end

  def create
    if params[:file].present?
      begin
        importer = GoodreadsCsvImporter.new(params[:file].path)
        result = importer.import
        
        if result[:success]
          redirect_to books_path, notice: "Successfully imported #{result[:count]} books from Goodreads!"
        else
          redirect_to new_import_path, alert: "Import failed: #{result[:error]}"
        end
      rescue => e
        redirect_to new_import_path, alert: "Import failed: #{e.message}"
      end
    else
      redirect_to new_import_path, alert: "Please select a CSV file to import."
    end
  end
end
