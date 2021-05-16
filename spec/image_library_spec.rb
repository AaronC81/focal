require_relative '../app/image_library'
require 'fileutils'

RSpec.describe Focal::ImageLibrary do
  let(:subject) { create_test_copy }

  def create_test_copy
    # Generate a dir under /tmp
    random_path_part = 20.times.map { ('a'..'z').to_a.sample }.join
    test_path = "/tmp/focal_test_#{random_path_part}"

    # Copy the library contents there
    FileUtils.cp_r(TEST_LIBRARY_PATH, test_path)

    # Instantiate and return new library
    new_library = described_class.new(test_path)
    @library_test_copies ||= []
    @library_test_copies << new_library
    new_library
  end

  def rel_path(*parts)
    File.join(subject.library_path, *parts)
  end

  after :each do
    @library_test_copies.each do |copy|
      # Sanity check! Let's not nuke any systems
      raise 'unusual library test copy path' \
        unless copy.library_path.start_with?('/tmp/')

      # Remove the test library
      FileUtils.rm_rf(copy.library_path)
    end if @library_test_copies&.any? && !ENV['FOCAL_KEEP_LIBRARY_TEST_COPIES']

    @library_test_copies = []
  end

  it 'loads albums' do
    expect(subject.albums.map(&:name)).to eq ['Library A', 'Library B']
  end

  it 'loads images from albums' do
    album = subject.album_by_name('Library A')

    expect(album.images).to match_array([
      have_attributes(name: 'Geese1.jpg', archived: false),
      have_attributes(name: 'Geese2.jpg', archived: false),
    ])

    expect(album.images(include_archived: true)).to match_array([
      have_attributes(name: 'Geese1.jpg', archived: false),
      have_attributes(name: 'Geese2.jpg', archived: false),
      have_attributes(name: 'Geese3.jpg', archived: true),
    ])
  end

  it 'archives and unarchives images' do
    subject.album_by_name("Library A").image_by_name("Geese1.jpg").archive
    subject.album_by_name("Library A").image_by_name("Geese3.jpg").unarchive

    subject.album_by_name("Library B").image_by_name("Ducks1.jpg").archive

    expect(File.exist?(rel_path("Library A", "Archived", "Geese1.jpg"))).to eq true
    expect(File.exist?(rel_path("Library A", "Geese1.jpg"))).to eq false

    expect(File.exist?(rel_path("Library A", "Archived", "Geese3.jpg"))).to eq false
    expect(File.exist?(rel_path("Library A", "Geese3.jpg"))).to eq true

    expect(File.exist?(rel_path("Library B", "Archived", "Ducks1.jpg"))).to eq true
    expect(File.exist?(rel_path("Library B", "Ducks1.jpg"))).to eq false
  end

  it 'assigns images a unique and consistent thumbnail ID' do
    img1 = subject.album_by_name("Library A").image_by_name("Geese1.jpg")
    img2 = subject.album_by_name("Library A").image_by_name("Geese2.jpg")

    img1_id_before_archive = img1.thumbnail_id
    img1.archive
    img1_id_after_archive = img1.thumbnail_id
    img1.unarchive
    img1_id_after_unarchive = img1.thumbnail_id

    expect(img1_id_before_archive).to eq img1_id_after_archive
    expect(img1_id_before_archive).to eq img1_id_after_unarchive

    expect(img1_id_before_archive).not_to eq img2.thumbnail_id
  end

  it 'generates thumbnails' do
    img = subject.album_by_name("Library A").image_by_name("Geese1.jpg")

    expect(img.thumbnail_generated?).to eq false
    img.generate_thumbnail
    expect(img.thumbnail_generated?).to eq true

    expect(File.exist?(img.thumbnail_path)).to eq true
  end
end
