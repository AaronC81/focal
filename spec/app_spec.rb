ENV['RACK_ENV'] = 'test'

require 'rack/test'
require_relative '../app/image_library'
require_relative '../app/app'

RSpec.describe Focal::App do
  include Rack::Test::Methods

  let(:app) { described_class }

  before :each do
    app.opts[:image_library] = create_test_copy
  end

  def authenticate
    post '/authenticate', { password: TEST_LIBRARY_PASSWORD }
    expect(last_response.status).to eq 302
  end

  context '/img endpoint' do
    it 'returns valid images' do
      get '/img/Library%20A/Geese1.jpg'
      expect(last_response).to be_ok
      expect(last_response.content_type).to eq 'image/jpeg'
      expect(last_response.length).to be > 0
    end

    it 'returns alternative formats for images' do
      get '/img/Library%20A/Geese1.jpg/format/.arw'
      expect(last_response).to be_ok
      # Rack might add the MIME for Sony Alpha Raw at some point, so just test
      # that we aren't assuming everything's a JPEG
      # (Currently it's sent as an octet stream)
      expect(last_response.content_type).not_to eq 'image/jpeg'
      expect(last_response.length).to be > 0
    end

    it '404s on missing images' do
      get '/img/Library%20A/Geese4.jpg'
      expect(last_response.status).to eq 404
    end

    it '404s on missing formats' do
      get '/img/Library%20A/Geese1.jpg/format/.png'
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
      it 'requires authentication' do
        post '/img/Library%20A/Geese1.jpg/archive'
        expect(last_response.status).to eq 401
      end

      it 'can archive images' do
        authenticate

        post '/img/Library%20A/Geese1.jpg/archive'
        expect(last_response.status).to eq 200

        post '/img/Library%20A/Geese1.jpg/archive'
        expect(last_response.status).to eq 204
      end

      it 'can unarchive images' do
        authenticate

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

  context '/cover endpoint' do
    it 'returns valid covers' do
      get '/cover/Library%20A'
      expect(last_response).to be_ok
      expect(last_response.content_type).to eq 'image/png'
      expect(last_response.length).to be > 0
    end
  end

  context '/album endpoint' do
    context '/visibility endpoint' do
      it 'requires authentication' do
        post '/album/Library+A/visibility', {
          "album_visibility" => "public",
          "album_archive_visibility" => "private",
        }
        expect(last_response).not_to be_ok
      end

      it 'allows setting valid visibility' do
        authenticate
        post '/album/Library+A/visibility', {
          "album_visibility" => "public",
          "album_archive_visibility" => "private",
        }
        expect(last_response).to be_ok
      end

      it 'rejects invalid visibility' do
        authenticate
        post '/album/Library+A/visibility', {
          "album_visibility" => "invalid",
          "album_archive_visibility" => "private",
        }
        expect(last_response.status).to eq 400
      end
    end
  end
end
