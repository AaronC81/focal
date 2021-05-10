module Focal
  class ImageLibrary
    ARCHIVED_DIR_NAME = 'Archived'

    Album = Struct.new('Album', :image_library, :name) do
      def path
        File.join(image_library.library_path, name)
      end

      def images(include_archived: false)
        image_library.album_images(self, include_archived: include_archived)
      end
    end

    Image = Struct.new('Image', :album, :name, :archived) do
      def archived?; archived; end

      def path
        if archived?
          File.join(album.path, name)
        else
          File.join(album.path, ARCHIVED_DIR_NAME, name)
        end
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
  end
end
