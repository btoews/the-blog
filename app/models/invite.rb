class Invite
  REDIS_KEY = "invite_nonces"

  def self.generate(user)
    raise ArgumentError unless user
    new(user: user).token
  end

  def self.from_token(token)
    raise ArgumentError unless token
    new(token: token)
  end

  def initialize(user: nil, token: nil)
    @uid = user.id if user
    @user = user
    @token = token
  end

  def valid?
    user && user.admin? && !redeemed?
  end

  def token
    @token ||= generate_token
  end

  def redeem!
    redis.sadd(REDIS_KEY, nonce)
  end

  private

  def user
    @user ||= User.find(uid)
  end

  def uid
    @uid ||= parse_token["uid"]
  end

  def nonce
    @nonce ||= SecureRandom.hex(8)
  end

  def redeemed?
    redis.sismember(REDIS_KEY, nonce)
  end

  def redis
    Rails.application.config.redis
  end

  def generate_token
    message_encryptor.encrypt_and_sign(uid: uid, nonce: nonce)
  end

  def parse_token
    message_encryptor.decrypt_and_verify(token)
  end

  def message_encryptor
    @message_encryptor||= ActiveSupport::MessageEncryptor.new(
      Rails.application.config.crypto_key,
      'aes-256-cbc',
      serializer: JSON
    )
  end
end
