require 'sinatra/base'
require 'cgi'

module Focal
  class App < Sinatra::Application
    get '/img/:album/:image' do
      album_name = CGI.unescape(params['album'])
      image_name = CGI.unescape(params['image'])

      album = settings.image_library.album_by_name(album_name)
      halt 404, 'Album not found' if album.nil?

      image = album.image_by_name(image_name)
      halt 404, 'Image not found' if image.nil?

      send_file image.path
    end

    get '/album/:name' do
      album_name = CGI.unescape(params['name'])

      album = settings.image_library.album_by_name(album_name)
      halt 404, 'Album not found' if album.nil?

      erb :album, locals: { images: album.images }
    end
  end
end
