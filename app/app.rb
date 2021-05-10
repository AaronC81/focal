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

      include_archived = !!params['archived']

      erb :album, locals: { images: album.images(include_archived: include_archived) }
    end

    get '/' do
      albums = settings.image_library.albums

      erb :index, locals: { albums: albums }
    end
  end
end
