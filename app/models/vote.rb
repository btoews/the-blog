class Vote < ActiveRecord::Base
  belongs_to :user
  belongs_to :post

  validates :user, uniqueness: {scope: :post, message: 'can only vote once per post'}
  validates :value, inclusion: { in: [1, -1], message: 'can only vote +1/-1' }
end
