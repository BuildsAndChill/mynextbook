# app/controllers/imports_controller.rb
# Rôle : afficher le formulaire d’upload + traiter l’import CSV via le service.
class ImportsController < ApplicationController
  before_action :authenticate_user!
  
  def new
  end

  def create
    Rails.logger.info "Import request received. File present: #{params[:file].present?}"
    Rails.logger.info "Current user: #{current_user.id}"
    
    if params[:file].present?
      begin
        Rails.logger.info "Starting CSV import with file: #{params[:file].original_filename}"
        Rails.logger.info "File path: #{params[:file].path}"
        
        importer = GoodreadsCsvImporter.new(params[:file].path, current_user)
        result = importer.import
        
        Rails.logger.info "Import result: #{result.inspect}"
        
        if result[:success]
          redirect_to books_path, notice: "Successfully imported #{result[:count]} books from Goodreads!"
        else
          redirect_to new_import_path, alert: "Import failed: #{result[:error]}"
        end
      rescue => e
        Rails.logger.error "Import error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        redirect_to new_import_path, alert: "Import failed: #{e.message}"
      end
    else
      redirect_to new_import_path, alert: "Please select a CSV file to import."
    end
  end
end
