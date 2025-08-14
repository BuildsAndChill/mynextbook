class RemoveUserRefinements < ActiveRecord::Migration[8.0]
  def up
    # Supprimer la table user_refinements si elle existe
    if table_exists?(:user_refinements)
      drop_table :user_refinements
    end
  end

  def down
    # Recréer la table user_refinements si nécessaire (rollback)
    create_table :user_refinements do |t|
      t.references :user, null: false, foreign_key: true
      t.text :refinement_text
      t.text :context
      t.timestamps
    end
  end
end
