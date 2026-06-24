# frozen_string_literal: true

require_relative 'spec_helper'
require 'securerandom'
require 'tempfile'

RSpec.describe 'Formats API', type: :request do
  describe 'GET /library/api/rest/v1/formats' do
    it 'returns paginated list of formats' do
      get '/library/api/rest/v1/formats?per_page=5'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['items']).to be_an(Array)
      expect(json['items'].size).to eq(5)
      expect(json['pagination']).to include('page', 'per_page', 'total', 'total_pages')
    end

    it 'filters by source' do
      get '/library/api/rest/v1/formats?source=PRONOM&per_page=10'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['source']).to eq('PRONOM')
      end
    end

    it 'filters by mimetype' do
      get '/library/api/rest/v1/formats?mimetype=image/jpeg&per_page=10'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['mimetypes']).to include('image/jpeg')
      end
    end

    it 'filters by extension' do
      get '/library/api/rest/v1/formats?extension=pdf&per_page=10'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['extensions']).to include('pdf')
      end
    end

    it 'searches by query' do
      get '/library/api/rest/v1/formats?q=WAVE&per_page=10'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['name'].downcase).to include('wave')
      end
    end
  end

  it 'creates a new format' do
    uid = "test-fmt-#{SecureRandom.hex(6)}"
    payload = { uid:, name: 'Test Format', source: 'TEST' }
    post '/library/api/rest/v1/formats', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    expect(last_response).to be_ok
    json = JSON.parse(last_response.body)
    expect(json['uid']).to eq(uid)
    expect(json['name']).to eq('Test Format')
    expect(json['source']).to eq('TEST')
  end

  it 'returns 400 if payload is invalid' do
    payload = { name: 'Test Format', source: 'TEST' }
    post '/library/api/rest/v1/formats', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    expect(last_response.status).to eq(400)
    json = JSON.parse(last_response.body)
    expect(json['error']).to include('required')
  end

  describe 'GET /library/api/rest/v1/formats/search' do
    it 'requires q parameter' do
      get '/library/api/rest/v1/formats/search'
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end

    it 'returns search results' do
      get '/library/api/rest/v1/formats/search?q=Broadcast'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['items']).to be_an(Array)
      expect(json['items'].size).to be > 0
    end
  end

  describe 'GET /library/api/rest/v1/formats/detail' do
    it 'returns format details' do
      uid = "test-fmt-detail-#{SecureRandom.hex(6)}"
      payload = {
        uid:,
        name: 'Detail Format',
        source: 'TEST',
        mimetypes: ['application/x-detail'],
        extensions: ['detail']
      }
      post '/library/api/rest/v1/formats', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response).to be_ok

      get "/library/api/rest/v1/formats/detail?uid=#{uid}"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['uid']).to eq(uid)
      expect(json['name']).to eq('Detail Format')
      expect(json['mimetypes']).to be_an(Array)
      expect(json['extensions']).to be_an(Array)
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

  describe 'GET /library/api/rest/v1/formats/relations' do
    it 'returns format relations' do
      get '/library/api/rest/v1/formats/relations?uid=x-fmt/1'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json).to be_a(Hash)
    end

    it 'filters relations by type' do
      get '/library/api/rest/v1/formats/relations?uid=x-fmt/1&relation_types=has_format'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json).to be_a(Hash)
    end
  end

  describe 'GET /library/api/rest/v1/formats/related' do
    it 'returns related formats' do
      get '/library/api/rest/v1/formats/related?uid=x-fmt/1'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json).to be_a(Hash)
    end
  end

  describe 'GET /library/api/rest/v1/formats/tags' do
    it 'returns format tags' do
      get '/library/api/rest/v1/formats/tags?uid=x-fmt/1'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json).to be_an(Array)
    end
  end

  describe 'PUT /library/api/rest/v1/formats/detail' do
    it 'updates an existing format' do
      uid = "test-fmt-#{SecureRandom.hex(6)}"
      payload = { uid:, name: 'Old Name', source: 'TEST' }
      post '/library/api/rest/v1/formats', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response).to be_ok

      update_payload = { uid:, name: 'Updated Name' }
      put "/library/api/rest/v1/formats/detail?uid=#{uid}", update_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['uid']).to eq(uid)
      expect(json['name']).to eq('Updated Name')
    end
  end

  describe 'DELETE /library/api/rest/v1/formats/detail' do
    it 'deletes an existing format' do
      uid = "test-fmt-#{SecureRandom.hex(6)}"
      payload = { uid:, name: 'ToDelete', source: 'TEST' }
      post '/library/api/rest/v1/formats', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response).to be_ok

      delete "/library/api/rest/v1/formats/detail?uid=#{uid}"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['deleted']).to eq(uid)

      get "/library/api/rest/v1/formats/detail?uid=#{uid}"
      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /library/api/rest/v1/formats/upload' do
    it 'uploads formats from YAML file' do
      uid = "test-fmt-upload-yaml-#{SecureRandom.hex(6)}"
      yaml = <<~YAML
        - uid: #{uid}
          name: Uploaded YAML Format
          source: TEST
          mimetypes:
            - application/x-upload-yaml
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
      expect(json['items'].first['uid']).to eq(uid)
      expect(json['items'].first['name']).to eq('Uploaded YAML Format')
    end

    it 'uploads formats from JSON file' do
      uid = "test-fmt-upload-json-#{SecureRandom.hex(6)}"
      payload = [{ uid:, name: 'Uploaded JSON Format', source: 'TEST', extensions: ['upjson'] }]

      Tempfile.create(['formats', '.json']) do |file|
        file.write(payload.to_json)
        file.rewind

        post '/library/api/rest/v1/formats/upload',
             { file: Rack::Test::UploadedFile.new(file.path, 'application/json') }
      end

      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['count']).to eq(1)
      expect(json['items'].first['uid']).to eq(uid)
      expect(json['items'].first['name']).to eq('Uploaded JSON Format')
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
