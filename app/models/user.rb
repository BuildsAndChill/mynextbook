class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
         
  has_many :user_readings, dependent: :destroy
  has_many :books, through: :user_readings, source: :book_metadata
  has_many :user_book_feedbacks, dependent: :destroy
  has_many :user_refinements, dependent: :destroy
  
  # Get user's reading preferences for AI recommendations
  def reading_preferences
    UserBookFeedback.user_preferences(self)
  end
  
  # Get feedback summary for AI
  def feedback_summary
    UserBookFeedback.feedback_summary_for_ai(self)
  end
  
  # Get refinement history
  def refinement_history(limit = 10)
    UserRefinement.refinement_history(self, limit)
  end
  
  # Get common refinements
  def common_refinements(limit = 5)
    UserRefinement.common_refinements(self, limit)
  end
  
  # Get imported books count (for display purposes)
  def imported_books_count
    books.imported.count
  end
  
  # Get manual books count (for display purposes)
  def manual_books_count
    books.manual.count
  end
end
