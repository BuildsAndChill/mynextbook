class UserRefinement < ApplicationRecord
  belongs_to :user
  
  validates :refinement_text, presence: true
  validates :context, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :for_context, ->(context) { where(context: context) if context.present? }
  
  # Get user's refinement history
  def self.refinement_history(user, limit = 10)
    user.user_refinements.recent.limit(limit)
  end
  
  # Get most common refinements for AI learning
  def self.common_refinements(user, limit = 5)
    user.user_refinements
        .group(:refinement_text)
        .order('count(*) DESC')
        .limit(limit)
        .pluck(:refinement_text)
  end
  
  # Create refinement from user input
  def self.create_from_input(user, refinement_text, context)
    create!(
      user: user,
      refinement_text: refinement_text,
      context: context
    )
  end
end
