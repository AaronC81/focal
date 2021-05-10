ENV['RACK_ENV'] = 'test'

require 'rack/test'
require_relative '../app/image_library'
require_relative '../app/app'

RSpec.describe Focal::App do
  include Rack::Test::Methods

  let(:image_library) { Focal::ImageLibrary.new(TEST_LIBRARY_PATH) }
  let(:app) { described_class.new(image_library) }

  before do
    app.set :image_library, image_library
  end

  context '/img endpoint' do
    it 'returns valid images' do
      get '/img/Library%20A/Geese1.jpg'
      expect(last_response).to be_ok
      expect(last_response.content_type).to eq 'image/jpeg'
      expect(last_response.length).to be > 0
    end

    it '404s on missing images' do
      get '/img/Library%20A/Geese4.jpg'
      expect(last_response.status).to eq 404
    end

    it '404s on missing albums' do
      get '/img/Library%20C/Geese1.jpg'
      expect(last_response.status).to eq 404
    end

    it 'does not allow arbitrary paths relative to the image library' do
      get '/img/../spec_helper.rb'
      expect(last_response.status).to eq 404
    end
  end
end
