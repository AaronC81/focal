require 'sinatra/base'
require 'sinatra/namespace'
require 'cgi'

module Focal
  class App < Sinatra::Application
    register Sinatra::Namespace

    def request_image
      album_name = CGI.unescape(params['album'])
      image_name = CGI.unescape(params['image'])

      album = settings.image_library.album_by_name(album_name)
      halt 404, 'Album not found' if album.nil?

      image = album.image_by_name(image_name)
      halt 404, 'Image not found' if image.nil?
      
      image
    end
    
    namespace '/img/:album/:image' do
      get do
        send_file request_image.path
      end

      post '/archive' do
        image = request_image
        if image.archived?
          status 204
        else
          image.archive
          status 200
        end
      end

      post '/unarchive' do
        image = request_image
        if image.archived?
          image.unarchive
          status 200
        else
          status 204
        end
      end
    end

    get '/thumb/:album/:image' do
      image = request_image
      image.ensure_thumbnail_generated
      send_file image.thumbnail_path
    end

    get '/album/:name' do
      album_name = CGI.unescape(params['name'])

      album = settings.image_library.album_by_name(album_name)
      halt 404, 'Album not found' if album.nil?

      include_archived = !!params['archived']

      erb :album, locals: {
        include_archived: include_archived,
        album: album,
        images: album.images(include_archived: include_archived)
      }
    end

    get '/' do
      albums = settings.image_library.albums

      erb :index, locals: { albums: albums }
    end
  end
end
