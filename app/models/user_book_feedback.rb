class UserBookFeedback < ApplicationRecord
  belongs_to :user
  
  enum feedback_type: { like: 0, dislike: 1, save: 2, more_info: 3 }
  
  validates :book_title, presence: true
  validates :book_author, presence: true
  validates :feedback_type, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :likes, -> { where(feedback_type: :like) }
  scope :dislikes, -> { where(feedback_type: :dislike) }
  scope :saves, -> { where(feedback_type: :save) }
  scope :for_book, ->(title, author) { where(book_title: title, book_author: author) }
  
  # Get user's reading preferences based on feedback
  def self.user_preferences(user)
    {
      likes: user.user_book_feedbacks.likes.recent.limit(20).pluck(:book_title, :book_author),
      dislikes: user.user_book_feedbacks.dislikes.recent.limit(20).pluck(:book_title, :book_author),
      saved: user.user_book_feedbacks.saves.recent.limit(20).pluck(:book_title, :book_author)
    }
  end
  
  # Check if user has already given feedback for a specific book
  def self.user_feedback_exists?(user, title, author, feedback_type)
    user.user_book_feedbacks.for_book(title, author).where(feedback_type: feedback_type).exists?
  end
  
  # Get feedback summary for AI recommendations
  def self.feedback_summary_for_ai(user)
    feedbacks = user.user_book_feedbacks.recent.limit(15)
    
    summary = {
      likes: feedbacks.likes.map { |f| "#{f.book_title} by #{f.book_author}" },
      dislikes: feedbacks.dislikes.map { |f| "#{f.book_title} by #{f.book_author}" },
      saved: feedbacks.saves.map { |f| "#{f.book_title} by #{f.book_author}" }
    }
    
    summary
  end
end
