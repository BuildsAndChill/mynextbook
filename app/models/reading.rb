class Reading < ApplicationRecord
  belongs_to :user
  
  validates :goodreads_book_id, presence: true
  validates :title, :author, presence: true
  validates :my_rating, numericality: { only_integer: true }, allow_nil: true
end
