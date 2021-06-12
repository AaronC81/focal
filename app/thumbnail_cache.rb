require_relative 'image_library'

module Focal
  module ThumbnailCache
    def self.prepare(library)
      return if @status == :in_progress || @status == :ready

      @thumbnails = {}
      @status = :in_progress

      library.albums.each do |album|
        album.images.each do |image|
          file = File.open(image.thumbnail_path, "rb")
          begin
            bytes = file.each_byte.map(&:chr).join
            @thumbnails[image.thumbnail_path] = bytes
          ensure
            file.close
          end
        end
      end

      puts "Thumbnail cache ready, contains #{@thumbnails.length} images"
      @status = :ready
    end

    def self.ready?
      @status == :ready
    end

    def self.cached?(image)
      ready? && !@thumbnails[image.thumbnail_path].nil?
    end

    def self.thumbnail(image)
      @thumbnails[image.thumbnail_path]
    end
  end
end
