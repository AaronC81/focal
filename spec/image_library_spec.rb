require_relative '../app/image_library'
require 'fileutils'

RSpec.describe Focal::ImageLibrary do
  let(:subject) { create_test_copy }

  def rel_path(*parts)
    File.join(subject.library_path, *parts)
  end

  before :each do
    subject.albums.each do |album|
      album.clear_thumbnails
    end
  end

  after :each do
    $library_test_copies.each do |copy|
      # Sanity check! Let's not nuke any systems
      raise 'unusual library test copy path' \
        unless copy.library_path.start_with?('/tmp/')

      # Remove the test library
      FileUtils.rm_rf(copy.library_path)
    end if $library_test_copies&.any? && !ENV['FOCAL_KEEP_LIBRARY_TEST_COPIES']

    $library_test_copies = []
  end

  it 'loads albums' do
    expect(subject.albums.map(&:name)).to eq ['Library A', 'Library B']
  end

  it 'loads images from albums' do
    album = subject.album_by_name('Library A')

    expect(album.images).to match_array([
      have_attributes(name: 'Geese1.jpg', archived: false, alternative_formats: ['.arw']),
      have_attributes(name: 'Geese2.jpg', archived: false, alternative_formats: []),
    ])

    expect(album.images(include_archived: true)).to match_array([
      have_attributes(name: 'Geese1.jpg', archived: false, alternative_formats: ['.arw']),
      have_attributes(name: 'Geese2.jpg', archived: false, alternative_formats: []),
      have_attributes(name: 'Geese3.jpg', archived: true, alternative_formats: ['.ARW']),
    ])

    expect(album.image_by_name("Geese1.jpg").alternative_format_details).to eq [{
      path: "#{subject.library_path}/Library A/Geese1.arw",
      url: "/img/Library%20A/Geese1.jpg/format/.arw",
      format: ".arw",
      description: "Sony Alpha Raw"
    }]
  end

  it 'archives and unarchives images' do
    subject.album_by_name("Library A").image_by_name("Geese1.jpg").archive
    subject.album_by_name("Library A").image_by_name("Geese3.jpg").unarchive

    subject.album_by_name("Library B").image_by_name("Ducks1.jpg").archive

    expect(File.exist?(rel_path("Library A", "Archived", "Geese1.jpg"))).to eq true
    expect(File.exist?(rel_path("Library A", "Archived", "Geese1.arw"))).to eq true
    expect(File.exist?(rel_path("Library A", "Geese1.jpg"))).to eq false
    expect(File.exist?(rel_path("Library A", "Geese1.arw"))).to eq false

    expect(File.exist?(rel_path("Library A", "Archived", "Geese3.jpg"))).to eq false
    expect(File.exist?(rel_path("Library A", "Archived", "Geese3.ARW"))).to eq false
    expect(File.exist?(rel_path("Library A", "Geese3.jpg"))).to eq true
    expect(File.exist?(rel_path("Library A", "Geese3.ARW"))).to eq true

    expect(File.exist?(rel_path("Library B", "Archived", "Ducks1.jpg"))).to eq true
    expect(File.exist?(rel_path("Library B", "Archived", "Ducks1.aRw"))).to eq true
    expect(File.exist?(rel_path("Library B", "Ducks1.jpg"))).to eq false
    expect(File.exist?(rel_path("Library B", "Ducks1.aRw"))).to eq false
  end

  it 'generates thumbnails' do
    img = subject.album_by_name("Library A").image_by_name("Geese1.jpg")

    expect(img.thumbnail_generated?).to eq false
    img.generate_thumbnail
    expect(img.thumbnail_generated?).to eq true

    expect(File.exist?(img.thumbnail_path)).to eq true
  end

  it 'allows thumbnails to be cleared' do
    img = subject.album_by_name("Library A").image_by_name("Geese1.jpg")

    expect(img.thumbnail_generated?).to eq false
    img.generate_thumbnail
    expect(img.thumbnail_generated?).to eq true

    subject.album_by_name("Library A").clear_thumbnails
    expect(img.thumbnail_generated?).to eq false
  end

  it 'generates covers' do
    album = subject.album_by_name("Library A")
    
    expect(album.cover_generated?).to eq false
    album.generate_cover
    expect(album.cover_generated?).to eq true

    expect(File.exist?(album.cover_path)).to eq true
  end

  it 'can calculate image sizes' do
    img = subject.album_by_name("Library A").image_by_name("Geese1.jpg")

    expect(img.size).to eq [6000, 4000]
    expect(img.thumbnail_size).to eq [300, 200]
  end

  context 'settings' do
    it 'can be loaded' do
      expect(subject.album_by_name("Library A").settings).to eq({
        "album_visibility" => "public",
        "album_archive_visibility" => "public",
      })

      expect(subject.album_by_name("Library B").settings).to eq({
        "album_visibility" => "public",
        "album_archive_visibility" => Focal::ImageLibrary::ALBUM_SETTINGS_DEFAULTS["album_archive_visibility"],
      })
    end

    it 'can be changed' do
      album = subject.album_by_name("Library A")
      album.save_setting("album_visibility", "private")

      expect(album.settings).to eq({
        "album_visibility" => "private",
        "album_archive_visibility" => "public",
      })
    end

    it 'can be loaded and changed using accessor methods' do
      album = subject.album_by_name("Library A")

      expect(album.settings).to eq({
        "album_visibility" => "public",
        "album_archive_visibility" => "public",
      })
      expect(album.album_visibility).to eq "public"

      album.album_visibility = "private"

      expect(album.settings).to eq({
        "album_visibility" => "private",
        "album_archive_visibility" => "public",
      })
      expect(album.album_visibility).to eq "private"
    end

    it 'can create a settings file when one doesn\'t exist' do
      FileUtils.mkdir(rel_path("Library C"))

      album = subject.album_by_name("Library C")
      album.album_visibility = "public"
      expect(album.album_visibility).to eq "public"
    end
  end
end
