class User < Sequel::Model
  def self.hash(u,p)
    require 'digest/md5'
    Digest::MD5.hexdigest("#{u}#{p}")
  end

  def cookie
    require 'digest/sha1'
    Digest::SHA1.hexdigest("#{username}#{hash}")
  end
end
