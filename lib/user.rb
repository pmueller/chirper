require 'digest/md5'
require 'digest/sha1'

class User < Sequel::Model
  def self.hash_val(username, password)
    Digest::MD5.hexdigest("#{username}#{password}")
  end

  def cookie
    Digest::SHA1.hexdigest("#{username}#{hash}")
  end
end
