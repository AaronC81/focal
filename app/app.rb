require 'roda'
require 'cgi'
require 'pathname'
require 'securerandom'

require_relative 'authentication'

module Focal
  class App < Roda
    plugin :sessions, secret: SecureRandom.uuid + SecureRandom.uuid
    plugin :halt
    plugin :sinatra_helpers
    plugin :render, views: File.join(__dir__, "views")
    plugin :public, root: File.join(__dir__, "public")

    def authentication
      @authentication ||= Focal::Authentication.new(opts[:image_library].library_path)
      @authentication
    end

    def authenticated!(r)
      r.halt 401 unless authenticated?
    end

    def authenticated?
      !!session["authenticated"]
    end

    def send_file_or_accel(r, path)
      if opts[:x_accel]
        # We need a relative path
        path = Pathname.new(path)
        image_library_root = Pathname.new(opts[:image_library].library_path)
        relative_path = path.relative_path_from(image_library_root).to_s

        r.response.headers["X-Accel-Redirect"] = "/x-accel-library/#{relative_path}"
        r.response.headers["Content-Type"] = ""
        r.response.status = 200
      else
        send_file(path)
      end
    end

    def request_image(r, album, image)
      image_name = CGI.unescape(image)

      image = album.image_by_name(image_name)
      r.halt 404, 'Image not found' if image.nil?

      r.halt 401 if !album.archive_public? && image.archived? \
        && !authenticated?
      
      image
    end

    def request_album(r, album)
      album_name = CGI.unescape(album)

      album = opts[:image_library].album_by_name(album_name)
      r.halt 404, 'Album not found' if album.nil?

      r.halt 401 if !album.public? && !authenticated?
      
      album
    end

    route do |r|
      r.public

      r.on "img", String, String do |album, image|
        album = request_album(r, album)
        image = request_image(r, album, image)
                
        r.is do
          send_file_or_accel(r, image.path)
        end

        r.is "format", String do |format|  
          r.halt 404, 'Format not found' unless image.alternative_formats.include?(format)
  
          # We don't want the downloaded file to be called ".raw" or whatever
          # This will recommend a proper name like "DSC00001.raw" to the browser
          filename = File.basename(image.path(alternative_format: format))
          r.response['Content-Disposition'] = "attachment; filename=\"#{filename}\""
  
          send_file_or_accel(r, image.path(alternative_format: format))
        end

        r.post "archive" do
          authenticated!(r)

          if image.archived?
            r.halt 204
          else
            image.archive
            r.halt 200
          end
        end

        r.post 'unarchive' do
          authenticated!(r)
  
          if image.archived?
            image.unarchive
            r.halt 200
          else
            r.halt 204
          end
        end
      end

      r.on "cover", String do |album|
        album = request_album(r, album)

        r.is do
          album.ensure_cover_generated
          send_file_or_accel(r, album.cover_path)
        end

        r.post "regenerate" do
          authenticated!(r)
          album.generate_cover
        end
      end

      r.is "thumb", String, String do |album, image|
        album = request_album(r, album)
        image = request_image(r, album, image)

        image.ensure_thumbnail_generated
        send_file_or_accel(r, image.thumbnail_path)
      end

      r.on "album", String do |album|
        album = request_album(r, album)

        r.is do
          has_access_to_archived = !(!album.archive_public? && !authenticated?)
          include_archived = !!r.params['archived']
          r.halt 401 if include_archived && !has_access_to_archived
  
          archived_image_count = album.images(include_archived: true).select(&:archived?).length
  
          render(:album, locals: {
            include_archived: include_archived,
            album: album,
            images: album.images(include_archived: include_archived),
            archived_image_count: archived_image_count,
            has_access_to_archived: has_access_to_archived,
            authenticated: authenticated?,
          })
        end

        r.post "visibility" do
          authenticated!(r)

          (album.album_visibility = r.params["album_visibility"]) rescue (r.halt 400)
          (album.album_archive_visibility = r.params["album_archive_visibility"]) rescue (r.halt 400)  
        end
      end

      r.root do
        albums = opts[:image_library].albums.reject do |album|
          !album.public? && !authenticated?
        end
  
        render(:index, locals: { albums: albums, authenticated: authenticated? })
      end

      r.is "login" do
        render(:login, locals: { authenticated: authenticated? })
      end

      r.post "authenticate" do
        if r.params['password'] && authentication.correct_password?(r.params['password'])
          session["authenticated"] = true
          r.redirect '/'
        else
          r.halt 401, "Incorrect password"
        end
      end
  
      r.post '/unauthenticate' do
        session["authenticated"] = false
        r.redirect '/'
      end
    end
  end
end
