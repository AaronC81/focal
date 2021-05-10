require 'sinatra/base'
require 'cgi'

module Focal
  class App < Sinatra::Base
    attr_reader :image_library

    def initialize(image_library)
      @image_library = image_library
    end

    get '/img/:album/:image' do
      album_name = CGI.unescape(params['album'])
      image_name = CGI.unescape(params['image'])

      album = image_library.album_by_name(album_name)
      halt 404, 'Album not found' if album.nil?

      image = album.image_by_name(image_name)
      halt 404, 'Image not found' if image.nil?

      send_file image.path
    end
  end
end
