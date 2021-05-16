ENV['RACK_ENV'] = 'test'

require 'rack/test'
require_relative '../app/image_library'
require_relative '../app/app'

RSpec.describe Focal::App do
  include Rack::Test::Methods

  let(:app) { described_class }

  before :each do
    app.set :image_library, create_test_copy
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

    context 'modification' do
      it 'can archive images' do
        post '/img/Library%20A/Geese1.jpg/archive'
        expect(last_response.status).to eq 200

        post '/img/Library%20A/Geese1.jpg/archive'
        expect(last_response.status).to eq 204
      end

      it 'can unarchive images' do
        post '/img/Library%20A/Geese3.jpg/unarchive'
        expect(last_response.status).to eq 200

        post '/img/Library%20A/Geese3.jpg/unarchive'
        expect(last_response.status).to eq 204
      end
    end
  end

  context '/thumb endpoint' do
    it 'returns valid thumbnails' do
      get '/thumb/Library%20A/Geese1.jpg'
      expect(last_response).to be_ok
      expect(last_response.content_type).to eq 'image/jpeg'
      expect(last_response.length).to be > 0
    end
  end
end
