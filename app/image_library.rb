require 'fileutils'
require 'digest'
require 'rmagick'
require 'tmpdir'
require 'yaml'
require_relative 'epeg'

module Focal
  class ImageLibrary
    ARCHIVED_DIR_NAME = 'Archived'
    THUMBNAIL_DIR_NAME = '.FocalThumbs'
    THUMBNAIL_WIDTH = 300
    ALBUM_COVER_NAME = '__FocalAlbumCover.png'
    ALBUM_SETTINGS_NAME = ".Focal"

    PRIMARY_FORMATS = {
      ".jpg" => "JPEG",
      ".jpeg" => "JPEG",
    }
    ALTERNATIVE_FORMATS = {
      ".arw" => "Sony Alpha Raw"
    }

    ALBUM_SETTINGS_DEFAULTS = {
      "album_visibility" => "private",
      "album_archive_visibility" => "private",
    }

    Album = Struct.new('Album', :image_library, :name) do
      def path
        File.join(image_library.library_path, name)
      end

      def settings_path
        File.join(path, ALBUM_SETTINGS_NAME)
      end

      def settings
        if File.exist?(settings_path)
          file_contents = YAML.load_file(settings_path)
        else
          file_contents = {}
        end

        ALBUM_SETTINGS_DEFAULTS.merge(file_contents)
      end

      def save_setting(key, value)
        file_contents = YAML.load_file(settings_path)
        file_contents[key] = value
        File.write(settings_path, YAML.dump(file_contents))
      end

      def self.setting_accessor(name, values = nil)
        define_method(name.to_sym) do
          settings[name]
        end

        define_method("#{name}=".to_sym) do |value|
          raise "invalid value #{value} for setting #{name}" if values && !values.include?(value)
          save_setting(name, value)
        end
      end

      setting_accessor "album_visibility", ["public", "private"]
      setting_accessor "album_archive_visibility", ["public", "private"]

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
      
      def clear_thumbnails
        FileUtils.rm_rf(thumbnail_path)
      end

      def cover_path
        File.join(thumbnail_path, ALBUM_COVER_NAME)
      end

      def cover_url
        "/cover/#{CGI.escape(name)}"
      end

      def generate_cover
        ensure_thumbnail_dir_exists

        # TOOD: Use some kind of placeholder image
        return if images.empty?

        # Pick a set of random images and load them with RMagick
        images_for_cover = 6.times.map { images.sample.load_rmagick }

        # Crop each image into a square
        images_for_cover.each do |img|
          narrow_edge = img.columns > img.rows ? img.rows : img.columns
          img.crop!(Magick::CenterGravity, narrow_edge, narrow_edge)
          img.resize!(200, 200)        
        end

        # Create a new temporary directory
        tempdir = Dir.mktmpdir("FocalCover") do |dir|
          # Save them all as files in the temporary directory
          files = images_for_cover.map.with_index do |img, i|
            path = File.join(dir, "image#{i}.jpg")
            img.write(path)
            path
          end

          # Create an ImageList
          image_list = Magick::ImageList.new(*files)

          # Produce a 3x2 montage of images
          cover = image_list.montage do
            self.geometry = "200x200+5+5"
            self.tile = "3x2"
            self.background_color = "none"
          end[0]

          # Save it as the cover image
          cover.write(cover_path)
        end
      end

      def cover_generated?
        File.exist?(cover_path)
      end

      def ensure_cover_generated
        generate_cover unless cover_generated?
      end
    end

    Image = Struct.new('Image', :album, :name, :archived, :alternative_formats) do
      def archived?; archived; end

      def path(alternative_format: nil)
        if archived?
          path_if_archived(alternative_format: alternative_format)
        else
          path_if_not_archived(alternative_format: alternative_format)
        end
      end

      def archive
        return if archived?

        album.ensure_archive_exists
        FileUtils.move(path, path_if_archived)
        alternative_formats.each do |fmt|
          FileUtils.move(
            path_if_not_archived(alternative_format: fmt),
            path_if_archived(alternative_format: fmt),
          )
        end
        self.archived = true
      end

      def unarchive
        return unless archived?

        FileUtils.move(path, path_if_not_archived)
        alternative_formats.each do |fmt|
          FileUtils.move(
            path_if_archived(alternative_format: fmt),
            path_if_not_archived(alternative_format: fmt),
          )
        end
        self.archived = false
      end

      def url(alternative_format: nil)
        if alternative_format
          "/img/#{CGI.escape(album.name)}/#{CGI.escape(name)}/format/#{CGI.escape(alternative_format)}"
        else
          "/img/#{CGI.escape(album.name)}/#{CGI.escape(name)}"
        end
      end

      def thumbnail_url(alternative_format: nil)
        if alternative_format
          "/thumb/#{CGI.escape(album.name)}/#{CGI.escape(name_format(alternative_format))}"
        else
          "/thumb/#{CGI.escape(album.name)}/#{CGI.escape(name)}"
        end
      end

      def thumbnail_path
        File.join(album.thumbnail_path, name)
      end

      def thumbnail_generated?
        File.exist?(thumbnail_path)
      end

      def generate_thumbnail
        album.ensure_thumbnail_dir_exists

        EPEG.create_thumbnail(path, thumbnail_path, width: THUMBNAIL_WIDTH, preserve: true)
      end

      def ensure_thumbnail_generated
        generate_thumbnail unless thumbnail_generated?
      end

      def load_rmagick
        Magick::Image.read(path).first
      end

      def alternative_format_details
        alternative_formats.map do |alt_fmt|
          {
            path: path(alternative_format: alt_fmt),
            url: url(alternative_format: alt_fmt),
            format: alt_fmt,
            description: ALTERNATIVE_FORMATS[alt_fmt.downcase]
          }
        end
      end

      protected

      def path_if_archived(alternative_format: nil)
        if alternative_format
          File.join(album.path, ARCHIVED_DIR_NAME, name_format(alternative_format))
        else
          File.join(album.path, ARCHIVED_DIR_NAME, name)
        end
      end

      def path_if_not_archived(alternative_format: nil)
        if alternative_format
          File.join(album.path, name_format(alternative_format))
        else
          File.join(album.path, name)
        end
      end

      def name_format(format)
        "#{File.basename(name, ".*")}#{format}"
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
      alternative_format_paths = []

      images = Dir[File.join(album.path, '*')]
        .select { |path| File.file?(path) }
        .map do |path|
          if primary_format?(path)
            Image.new(album, File.basename(path), false, [])
          elsif alternative_format?(path)
            alternative_format_paths << path
            nil
          else
            nil
          end
        end.compact

      if include_archived
        album_archived_path = File.join(album.path, ARCHIVED_DIR_NAME)
        archived_images = Dir[File.join(album_archived_path, '*')]
          .select { |path| File.file?(path) }
          .map do |path|
            if primary_format?(path)
              Image.new(album, File.basename(path), true, [])
            elsif alternative_format?(path)
              alternative_format_paths << path
              nil
            else
              nil
            end
          end.compact

        images.push(*archived_images)
      end

      # Look through the alternative format paths we found and see if they match
      # any loaded images
      images.each do |image|
        image.alternative_formats = alternative_format_paths
          .select do |alt_path|
            File.basename(alt_path, ".*") == File.basename(image.name, ".*")
          end
          .map { |alt_path| File.extname(alt_path) }
      end

      images.sort_by(&:name)
    end

    def image_by_name(album, name)
      album.images(include_archived: true).find { |image| image.name == name }
    end

    protected

    def primary_format?(file)
      PRIMARY_FORMATS.keys.map(&:downcase).include?(File.extname(file).downcase)
    end

    def alternative_format?(file)
      ALTERNATIVE_FORMATS.keys.map(&:downcase).include?(File.extname(file).downcase)
    end
  end
end
