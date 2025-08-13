# app/controllers/imports_controller.rb
# Rôle : afficher le formulaire d'upload + traiter l'import CSV via le service.
class ImportsController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token, only: [:create]
  
  def new
  end

  def create
    # Completely disable session for CSV import to prevent CookieOverflow
    request.session_options[:skip] = true
    session.clear if session
    
    if params[:file].present?
      file = params[:file]
      
      # Validate file type
      unless file.content_type == 'text/csv' || file.original_filename.end_with?('.csv')
        redirect_to new_import_path, alert: "Please select a valid CSV file."
        return
      end
      
      # Validate file size (max 10MB)
      if file.size > 10.megabytes
        redirect_to new_import_path, alert: "File too large. Maximum size is 10MB."
        return
      end
      
      begin
        importer = GoodreadsCsvImporter.new(file.tempfile, current_user)
        result = importer.import
        
        if result[:success]
          # Redirect to library with imported books filter and success message
          redirect_to books_path(imported: true), notice: "Successfully imported #{result[:count]} books from Goodreads! Here are your imported books:"
        else
          redirect_to new_import_path, alert: "Import failed: #{result[:error]}"
        end
        
      rescue => e
        Rails.logger.error "Import error: #{e.message}"
        redirect_to new_import_path, alert: "Import failed: #{e.message}"
      end
    else
      redirect_to new_import_path, alert: "Please select a CSV file to import."
    end
  end
end
