class CreateUserRefinements < ActiveRecord::Migration[8.0]
  def change
    create_table :user_refinements do |t|
      t.references :user, null: false, foreign_key: true
      t.text :refinement_text
      t.text :context

      t.timestamps
    end
  end
end
