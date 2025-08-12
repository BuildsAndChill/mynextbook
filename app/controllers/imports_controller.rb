# app/controllers/imports_controller.rb
# Rôle : afficher le formulaire d’upload + traiter l’import CSV via le service.
class ImportsController < ApplicationController
  # GET /imports/new
  # Affiche un simple formulaire <input type="file"> pour uploader le CSV Goodreads
  def new
  end

  # POST /imports
  # Reçoit le fichier, lance GoodreadsCsvImporter, et redirige vers /readings avec un résumé.
  def create
    file = params[:file]
    if file.blank?
      redirect_to new_import_path, alert: "Sélectionne un fichier CSV exporté depuis Goodreads."
      return
    end

    # Compter les lignes brutes (hors header)
    csv_line_count = CSV.read(file.tempfile, headers: true).size

    result = GoodreadsCsvImporter.new(file.tempfile).call

    msg = "Import terminé – créés: #{result.created}, mis à jour: #{result.updated}, ignorés: #{result.skipped} (Total DB: #{Reading.count})"
    msg += " | Lignes CSV: #{csv_line_count}"

    if result.errors.any?
      flash[:alert] = ["⚠️ Quelques lignes en erreur:", *result.errors.first(5)].join("\n")
    end

    redirect_to readings_path, notice: msg
  end
end
