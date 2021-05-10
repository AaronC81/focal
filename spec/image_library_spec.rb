require_relative '../app/image_library'

TEST_LIBRARY_PATH = File.expand_path(File.join(__dir__, 'test_library'))

RSpec.describe Focal::ImageLibrary do
  let(:subject) { described_class.new(TEST_LIBRARY_PATH) }

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
end
