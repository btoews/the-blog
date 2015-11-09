class Post < ActiveRecord::Base
  has_many :votes

  validates :name, presence: true
  validates :body, presence: true

  after_save :index

  def score
    votes.sum(:value)
  end

  def self.search(query)
    Rails.configuration.search_index.search query
  end

  private

  def index
    Rails.configuration.search_index.index(id, body)
  end
end
