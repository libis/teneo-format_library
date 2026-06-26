# frozen_string_literal: true

require_relative 'spec_helper'
require 'securerandom'
require 'tempfile'

RSpec.describe 'Formats API', openapi: { tags: ['Formats'] }, type: :request do
  def build_payload
    {
      uid: 'test-fmt-test',
      name: 'Test Format',
      source: 'TEST',
      mimetypes: ['application/test'],
      extensions: ['test']
    }
  end

  before(:example, with_payload: true) do
    @payload = build_payload
  end

  before(:example, with_format: true) do
    @payload = build_payload
    @format = Teneo::FormatLibrary::Format.from_hash_(data: @payload.transform_keys(&:to_s))
  end

  after(:example) do
    Teneo::FormatLibrary::Format[@payload&.fetch(:uid)]&.destroy
  end

  describe 'GET /library/api/rest/v1/formats', openapi: { summary: 'Get a list of formats' } do
    it 'returns paginated list of formats' do
      get '/library/api/rest/v1/formats?page=1&per_page=2'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['items']).to be_an(Array)
      expect(json['items'].size).to eq(2)
      expect(json['pagination']).to include('page', 'per_page', 'total', 'total_pages')
    end

    it 'filters by source', with_format: true do
      get "/library/api/rest/v1/formats?source=#{@format.source}&per_page=2"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['source']).to eq(@format.source)
      end
    end

    it 'filters by mimetype', with_format: true do
      get "/library/api/rest/v1/formats?mimetype=#{@format.mimetypes.first}&per_page=2"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['mimetypes']).to include(@format.mimetypes.first)
      end
    end

    it 'filters by extension', with_format: true do
      get "/library/api/rest/v1/formats?extension=#{@format.extensions.first}&per_page=2"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['extensions']).to include(@format.extensions.first)
      end
    end

    it 'searches by query', with_format: true do
      get "/library/api/rest/v1/formats?q=#{@format.name}&per_page=2"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['name']).to include(@format.name)
      end
    end
  end

  describe 'GET /library/api/rest/v1/formats/detail', openapi: { summary: 'Get format details' } do
    it 'returns format details', with_format: true do
      get "/library/api/rest/v1/formats/detail?uid=#{@format.uid}"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['uid']).to eq(@format.uid)
      expect(json['name']).to eq(@format.name)
      expect(json['mimetypes']).to eq(@format.mimetypes)
      expect(json['extensions']).to eq(@format.extensions)
    end

    it 'returns 400 without uid parameter' do
      get '/library/api/rest/v1/formats/detail'
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end

    it 'returns 404 for unknown format' do
      get '/library/api/rest/v1/formats/detail?uid=unknown/uid'
      expect(last_response.status).to eq(404)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('not found')
    end
  end

  describe 'POST /library/api/rest/v1/formats', openapi: { summary: 'Create a new format' } do
    it 'creates a new format', with_payload: true do
      post '/library/api/rest/v1/formats', @payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['uid']).to eq(@payload[:uid])
      expect(json['name']).to eq(@payload[:name])
      expect(json['source']).to eq(@payload[:source])
      expect(json['mimetypes']).to eq(@payload[:mimetypes])
      expect(json['extensions']).to eq(@payload[:extensions])

      format = Teneo::FormatLibrary::Format[@payload[:uid]]
      expect(format).not_to be_nil
      expect(format.name).to eq(@payload[:name])
      expect(format.source).to eq(@payload[:source])
      expect(format.mimetypes).to eq(@payload[:mimetypes])
      expect(format.extensions).to eq(@payload[:extensions])
      format.destroy
    end

    it 'returns 400 if payload is invalid', with_payload: true do
      payload = @payload.dup
      payload.delete(:uid)
      post '/library/api/rest/v1/formats', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end

    it 'returns 400 if format already exists', with_format: true do
      payload = @payload.dup
      payload.delete(:uid)
      post '/library/api/rest/v1/formats', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end
  end

  describe 'PUT /library/api/rest/v1/formats/detail', openapi: { summary: 'Update an existing format' } do
    it 'updates an existing format', with_format: true do
      uid = @format.uid
      update_payload = { uid:, name: 'Updated Name' }
      put "/library/api/rest/v1/formats/detail?uid=#{uid}", update_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['uid']).to eq(uid)
      expect(json['name']).to eq('Updated Name')

      format = Teneo::FormatLibrary::Format[uid]
      expect(format.name).to eq('Updated Name')
    end

    it 'returns 400 without uid parameter' do
      put '/library/api/rest/v1/formats/detail', { name: 'Updated Name' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end

    it 'returns 404 for unknown format' do
      put '/library/api/rest/v1/formats/detail?uid=unknown/uid', { name: 'Updated Name' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(404)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('not found')
    end
  end

  describe 'DELETE /library/api/rest/v1/formats/detail', openapi: { summary: 'Delete an existing format' } do
    it 'deletes an existing format', with_format: true do
      delete "/library/api/rest/v1/formats/detail?uid=#{@format.uid}"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['deleted']).to eq(@format.uid)

      format = Teneo::FormatLibrary::Format[@format.uid]
      expect(format).to be_nil
    end

    it 'returns 400 without uid parameter' do
      delete '/library/api/rest/v1/formats/detail'
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end

    it 'returns 404 for unknown format' do
      delete '/library/api/rest/v1/formats/detail?uid=unknown/uid'
      expect(last_response.status).to eq(404)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('not found')
    end
  end

  describe 'GET /library/api/rest/v1/formats/search', openapi: { summary: 'Search formats' } do
    it 'requires q parameter' do
      get '/library/api/rest/v1/formats/search'
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end

    it 'returns search results', with_format: true do
      get "/library/api/rest/v1/formats/search?q=#{@format.name}"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['items']).to be_an(Array)
      expect(json['items'].size).to be > 0
    end
  end

  describe 'GET /library/api/rest/v1/formats/relations', openapi: { summary: 'Get format relations' } do
    it 'returns format relations', with_format: true do
      get "/library/api/rest/v1/formats/relations?uid=#{@format.uid}"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json).to be_a(Hash)
    end

    it 'filters relations by type', with_format: true do
      get "/library/api/rest/v1/formats/relations?uid=#{@format.uid}&relation_types=has_format"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json).to be_a(Hash)
    end

    it 'returns 400 without uid parameter' do
      get '/library/api/rest/v1/formats/relations'
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end

    it 'returns 404 for unknown format' do
      get '/library/api/rest/v1/formats/relations?uid=unknown/uid'
      expect(last_response.status).to eq(404)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('not found')
    end
  end

  describe 'GET /library/api/rest/v1/formats/related', openapi: { summary: 'Get related formats' } do
    it 'returns related formats', with_format: true do
      get "/library/api/rest/v1/formats/related?uid=#{@format.uid}"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json).to be_a(Hash)
    end

    it 'returns 400 without uid parameter' do
      get '/library/api/rest/v1/formats/related'
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end

    it 'returns 404 for unknown format' do
      get '/library/api/rest/v1/formats/related?uid=unknown/uid'
      expect(last_response.status).to eq(404)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('not found')
    end
  end

  describe 'GET /library/api/rest/v1/formats/tags', openapi: { summary: 'Get format tags' } do
    it 'returns format tags', with_format: true do
      get "/library/api/rest/v1/formats/tags?uid=#{@format.uid}"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json).to be_an(Array)
    end

    it 'returns 400 without uid parameter' do
      get '/library/api/rest/v1/formats/tags'
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end

    it 'returns 404 for unknown format' do
      get '/library/api/rest/v1/formats/tags?uid=unknown/uid'
      expect(last_response.status).to eq(404)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('not found')
    end
  end

  describe 'POST /library/api/rest/v1/formats/upload', openapi: {
    summary: 'Upload formats from a file',
    example_mode: :none,
    enum: {
      format: %w[yaml json]
    }
  } do
    it 'uploads formats from YAML file', with_payload: true do
      yaml = <<~YAML
        - uid: #{@payload[:uid]}
          name: #{@payload[:name]}
          source: #{@payload[:source]}
          mimetypes:
            - #{@payload[:mimetypes].first}
          extensions:
            - #{@payload[:extensions].first}
      YAML

      Tempfile.create(['formats', '.yml']) do |file|
        file.write(yaml)
        file.rewind

        post '/library/api/rest/v1/formats/upload',
             { file: Rack::Test::UploadedFile.new(file.path, 'application/x-yaml') }
      end

      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['count']).to eq(1)
      expect(json['items'].first['uid']).to eq(@payload[:uid])
      expect(json['items'].first['name']).to eq(@payload[:name])
      expect(json['items'].first['source']).to eq(@payload[:source])
      expect(json['items'].first['mimetypes']).to eq(@payload[:mimetypes])
      expect(json['items'].first['extensions']).to eq(@payload[:extensions])

      format = Teneo::FormatLibrary::Format[@payload[:uid]]
      expect(format).not_to be_nil
      expect(format.name).to eq(@payload[:name])
      expect(format.source).to eq(@payload[:source])
      expect(format.mimetypes).to eq(@payload[:mimetypes])
      expect(format.extensions).to eq(@payload[:extensions])

      format.destroy
    end

    it 'uploads formats from JSON file', with_payload: true do
      payload = [@payload]
      Tempfile.create(['formats', '.json']) do |file|
        file.write(payload.to_json)
        file.rewind

        post '/library/api/rest/v1/formats/upload',
             { file: Rack::Test::UploadedFile.new(file.path, 'application/json') }
      end

      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['count']).to eq(1)
      expect(json['items'].first['uid']).to eq(@payload[:uid])
      expect(json['items'].first['name']).to eq(@payload[:name])
      expect(json['items'].first['source']).to eq(@payload[:source])
      expect(json['items'].first['mimetypes']).to eq(@payload[:mimetypes])
      expect(json['items'].first['extensions']).to eq(@payload[:extensions])

      format = Teneo::FormatLibrary::Format[@payload[:uid]]
      expect(format).not_to be_nil
      expect(format.name).to eq(@payload[:name])
      expect(format.source).to eq(@payload[:source])
      expect(format.mimetypes).to eq(@payload[:mimetypes])
      expect(format.extensions).to eq(@payload[:extensions])

      format.destroy
    end

    it 'returns 400 for invalid YAML payload' do
      invalid_yaml = "uid: test-fmt-broken\n  - invalid"

      post '/library/api/rest/v1/formats/upload?format=yaml',
           invalid_yaml,
           { 'CONTENT_TYPE' => 'application/x-yaml' }

      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).not_to be_nil
    end

    it 'returns 400 for invalid JSON payload' do
      Tempfile.create(['formats-invalid', '.json']) do |file|
        file.write('{"uid": "test-fmt-broken"')
        file.rewind

        post '/library/api/rest/v1/formats/upload',
             { file: Rack::Test::UploadedFile.new(file.path, 'application/json') }
      end

      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).not_to be_nil
    end

    it 'returns 400 for empty payload' do
      post '/library/api/rest/v1/formats/upload', '', { 'CONTENT_TYPE' => 'application/x-yaml' }

      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end

    it 'returns 400 for unsupported file extension' do
      Tempfile.create(['formats', '.txt']) do |file|
        file.write("uid: test-fmt-txt\nname: Unsupported\nsource: TEST\n")
        file.rewind

        post '/library/api/rest/v1/formats/upload',
             { file: Rack::Test::UploadedFile.new(file.path, 'text/plain') }
      end

      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('Unsupported upload format')
    end
  end
end
