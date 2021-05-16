require 'digest'

module Focal
  class Authentication
    attr_reader :library_path

    def initialize(library_path)
      @library_path = library_path
    end

    def authentication_path
      File.join(library_path, ".FocalAuthentication")
    end

    def load_password_hash
      if File.exist?(authentication_path)
        File.read(authentication_path).strip
      else
        nil
      end
    end

    def hash_password(plain_text_password)
      Digest::SHA2.hexdigest(plain_text_password)
    end

    def correct_password?(given_password)
      hash_password(given_password) == load_password_hash
    end

    def save_password(new_password)
      File.write(authentication_path, hash_password(new_password))
    end
  end
end
