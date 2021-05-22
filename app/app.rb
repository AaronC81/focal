require 'sinatra/base'
require 'sinatra/namespace'
require 'cgi'

require_relative 'authentication'

module Focal
  class App < Sinatra::Application
    register Sinatra::Namespace
    enable :sessions

    def authentication
      @authentication ||= Focal::Authentication.new(settings.image_library.library_path)
      @authentication
    end

    def authenticated!
      halt 401 unless authenticated?
    end

    def authenticated?
      !!session[:authenticated]
    end

    def request_image
      image_name = CGI.unescape(params['image'])

      image = request_album.image_by_name(image_name)
      halt 404, 'Image not found' if image.nil?
      
      image
    end

    def request_album
      album_name = CGI.unescape(params['album'])

      album = settings.image_library.album_by_name(album_name)
      halt 404, 'Album not found' if album.nil?
      
      album
    end
    
    namespace '/img/:album/:image' do
      get do
        send_file request_image.path
      end

      get '/format/:format' do
        img = request_image
        format = params['format']

        halt 404, 'Format not found' unless img.alternative_formats.include?(format)

        # We don't want the downloaded file to be called ".raw" or whatever
        # This will recommend a proper name like "DSC00001.raw" to the browser
        filename = File.basename(img.path(alternative_format: format))
        response['Content-Disposition'] = "attachment; filename=\"#{filename}\""

        send_file img.path(alternative_format: format)
      end

      post '/archive' do
        authenticated!

        image = request_image
        if image.archived?
          status 204
        else
          image.archive
          status 200
        end
      end

      post '/unarchive' do
        authenticated!

        image = request_image
        if image.archived?
          image.unarchive
          status 200
        else
          status 204
        end
      end
    end

    get '/cover/:album' do
      album = request_album
      album.ensure_cover_generated
      send_file album.cover_path
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

      archived_image_count = album.images(include_archived: true).select(&:archived?).length

      erb :album, locals: {
        include_archived: include_archived,
        album: album,
        images: album.images(include_archived: include_archived),
        archived_image_count: archived_image_count,
        authenticated: authenticated?,
      }
    end

    get '/' do
      albums = settings.image_library.albums

      erb :index, locals: { albums: albums, authenticated: authenticated? }
    end

    get '/login' do
      erb :login, locals: { authenticated: authenticated? }
    end

    post '/authenticate' do
      if params['password'] && authentication.correct_password?(params['password'])
        session[:authenticated] = true
        redirect '/'
      else
        halt 401, "Incorrect password"
      end
    end

    post '/unauthenticate' do
      session[:authenticated] = false
      redirect '/'
    end
  end
end
