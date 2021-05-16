require 'fileutils'
require 'digest'
require 'rmagick'

module Focal
  class ImageLibrary
    ARCHIVED_DIR_NAME = 'Archived'
    THUMBNAIL_DIR_NAME = '.FocalThumbs'
    THUMBNAIL_WIDTH = 300

    Album = Struct.new('Album', :image_library, :name) do
      def path
        File.join(image_library.library_path, name)
      end

      def images(include_archived: false)
        image_library.album_images(self, include_archived: include_archived)
      end

      def image_by_name(name)
        image_library.image_by_name(self, name)
      end

      def ensure_archive_exists
        FileUtils.mkdir_p(File.join(path, ARCHIVED_DIR_NAME))
      end

      def url
        "/album/#{CGI.escape(name)}"
      end

      def thumbnail_path
        File.join(path, THUMBNAIL_DIR_NAME)
      end
  
      def ensure_thumbnail_dir_exists
        FileUtils.mkdir_p(thumbnail_path)
      end
    end

    Image = Struct.new('Image', :album, :name, :archived) do
      def archived?; archived; end

      def path
        if archived?
          path_if_archived
        else
          path_if_not_archived
        end
      end

      def archive
        album.ensure_archive_exists
        FileUtils.move(path, path_if_archived)
        self.archived = true
      end

      def unarchive
        FileUtils.move(path, path_if_not_archived)
        self.archived = false
      end

      def url
        "/img/#{CGI.escape(album.name)}/#{CGI.escape(name)}"
      end

      def thumbnail_path
        File.join(album.thumbnail_path, name)
      end

      def thumbnail_generated?
        File.exist?(thumbnail_path)
      end

      def generate_thumbnail
        album.ensure_thumbnail_dir_exists

        rmagick_image = load_rmagick
        new_width = THUMBNAIL_WIDTH
        new_height = rmagick_image.y_resolution.to_i / (rmagick_image.x_resolution.to_i / new_width)

        rmagick_thumbnail = rmagick_image.thumbnail(new_width, new_height)
        rmagick_thumbnail.write(thumbnail_path)
      end

      def ensure_thumbnail_generated
        generate_thumbnail unless thumbnail_generated?
      end

      def load_rmagick
        Magick::Image.read(path).first
      end

      protected

      def path_if_archived
        File.join(album.path, ARCHIVED_DIR_NAME, name)
      end

      def path_if_not_archived
        File.join(album.path, name)
      end
    end

    attr_reader :library_path

    def initialize(library_path)
      @library_path = library_path
    end

    def albums
      Dir[File.join(library_path, '*')]
        .select { |path| File.directory?(path) }  
        .map { |path| Album.new(self, File.basename(path)) }
        .sort_by(&:name)
    end

    def album_by_name(name)
      albums.find { |album| album.name == name }
    end

    def album_images(album, include_archived: false)
      images = Dir[File.join(album.path, '*')]
        .select { |path| File.file?(path) }
        .map { |path| Image.new(album, File.basename(path), false) }

      if include_archived
        album_archived_path = File.join(album.path, ARCHIVED_DIR_NAME)
        archived_images = Dir[File.join(album_archived_path, '*')]
          .select { |path| File.file?(path) }
          .map { |path| Image.new(album, File.basename(path), true) }

        images.push(*archived_images)
      end

      images.sort_by(&:name)
    end

    def image_by_name(album, name)
      album.images(include_archived: true).find { |image| image.name == name }
    end
  end
end
