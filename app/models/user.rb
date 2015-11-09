class User < ActiveRecord::Base
  has_secure_password
  has_many :votes

  validates :login, uniqueness: true
end
