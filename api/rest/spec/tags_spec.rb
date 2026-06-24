# frozen_string_literal: true

require_relative 'spec_helper'
require 'securerandom'
require 'tempfile'

RSpec.describe 'Tags API', type: :request do
  describe 'GET /library/api/rest/v1/tags' do
    it 'returns paginated list of tags' do
      get '/library/api/rest/v1/tags?per_page=5'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['items']).to be_an(Array)
      expect(json['items'].size).to eq(5)
      expect(json['pagination']).to include('page', 'per_page', 'total', 'total_pages')
    end

    it 'filters by namespace' do
      get '/library/api/rest/v1/tags?namespace=be.libis.teneo&per_page=10'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['namespace']).to eq('be.libis.teneo')
      end
    end

    it 'filters by profile' do
      get '/library/api/rest/v1/tags?profile=classification&per_page=10'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['profile']).to eq('classification')
      end
    end
  end

  describe 'GET /library/api/rest/v1/tags/detail' do
    it 'returns tag details' do
      get '/library/api/rest/v1/tags/detail?tag=be.libis.teneo:BMP'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['tag']).to eq('be.libis.teneo:BMP')
      expect(json['name']).to eq('Device Independent Bitmap (DIP/BMP) images')
      expect(json['profile']).to eq('classification')
      expect(json['namespace']).to eq('be.libis.teneo')
    end

    it 'includes formats when requested' do
      get '/library/api/rest/v1/tags/detail?tag=be.libis.teneo:BMP&include_formats=true'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['formats']).to be_an(Array)
      expect(json['formats'].size).to be > 0
    end

    it 'includes ancestors when requested' do
      get '/library/api/rest/v1/tags/detail?tag=be.libis.teneo:BMP&include_ancestors=true'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['ancestors']).to be_an(Array)
      expect(json['ancestors'].any? { |a| a['tag'] == 'be.libis.teneo:IMAGE' }).to be true
    end

    it 'includes descendants when requested' do
      get '/library/api/rest/v1/tags/detail?tag=be.libis.teneo:IMAGE&include_descendants=true'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['descendants']).to be_an(Array)
      expect(json['descendants'].any? { |d| d['tag'] == 'be.libis.teneo:BMP' }).to be true
    end

    it 'returns 400 without tag parameter' do
      get '/library/api/rest/v1/tags/detail'
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end

    it 'returns 404 for unknown tag' do
      get '/library/api/rest/v1/tags/detail?tag=unknown:tag'
      expect(last_response.status).to eq(404)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('not found')
    end
  end

  describe 'GET /library/api/rest/v1/tags/formats' do
    it 'returns paginated formats for tag' do
      get '/library/api/rest/v1/tags/formats?tag=be.libis.teneo:BMP&per_page=5'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['items']).to be_an(Array)
      expect(json['items'].size).to be <= 5
      expect(json['pagination']).to include('page', 'per_page', 'total', 'total_pages')
    end

    it 'returns formats with uid and name' do
      get '/library/api/rest/v1/tags/formats?tag=be.libis.teneo:BMP&per_page=3'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['uid']).not_to be_nil
        expect(item['name']).not_to be_nil
      end
    end
  end

  describe 'POST /library/api/rest/v1/tags' do
    it 'creates a new tag' do
      tag_id = "test.ns:#{SecureRandom.hex(6)}"
      payload = { tag: tag_id, name: 'New Tag', profile: 'test' }
      post '/library/api/rest/v1/tags', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['tag']).to eq(tag_id)
      expect(json['name']).to eq('New Tag')
      expect(json['profile']).to eq('test')
    end
  end

  describe 'PUT /library/api/rest/v1/tags/detail' do
    it 'updates an existing tag' do
      # create tag first
      tag_id = "test.ns:#{SecureRandom.hex(6)}"
      payload = { tag: tag_id, name: 'Old Name', profile: 'test' }
      post '/library/api/rest/v1/tags', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response).to be_ok

      update_payload = { tag: tag_id, name: 'Updated Name' }
      put "/library/api/rest/v1/tags/detail?tag=#{tag_id}", update_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['tag']).to eq(tag_id)
      expect(json['name']).to eq('Updated Name')
    end
  end

  describe 'DELETE /library/api/rest/v1/tags/detail' do
    it 'deletes an existing tag' do
      # create tag first
      tag_id = "test.ns:#{SecureRandom.hex(6)}"
      payload = { tag: tag_id, name: 'ToDelete', profile: 'test' }
      post '/library/api/rest/v1/tags', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response).to be_ok

      delete "/library/api/rest/v1/tags/detail?tag=#{tag_id}"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['deleted']).to eq(tag_id)

      # subsequent GET should return 404
      get "/library/api/rest/v1/tags/detail?tag=#{tag_id}"
      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /library/api/rest/v1/tags/upload' do
    it 'uploads tags from YAML file' do
      tag_id = "test.ns:YAML_UPLOAD_#{SecureRandom.hex(6)}"
      yaml = <<~YAML
        - tag: #{tag_id}
          name: Uploaded YAML Tag
          profile: test
      YAML

      Tempfile.create(['tags', '.yml']) do |file|
        file.write(yaml)
        file.rewind

        post '/library/api/rest/v1/tags/upload',
             { file: Rack::Test::UploadedFile.new(file.path, 'application/x-yaml') }
      end

      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['count']).to eq(1)
      expect(json['items'].first['tag']).to eq(tag_id)
      expect(json['items'].first['name']).to eq('Uploaded YAML Tag')
    end

    it 'uploads tags from JSON file' do
      tag_id = "test.ns:JSON_UPLOAD_#{SecureRandom.hex(6)}"
      payload = [{ tag: tag_id, name: 'Uploaded JSON Tag', profile: 'test' }]

      Tempfile.create(['tags', '.json']) do |file|
        file.write(payload.to_json)
        file.rewind

        post '/library/api/rest/v1/tags/upload',
             { file: Rack::Test::UploadedFile.new(file.path, 'application/json') }
      end

      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['count']).to eq(1)
      expect(json['items'].first['tag']).to eq(tag_id)
      expect(json['items'].first['name']).to eq('Uploaded JSON Tag')
    end

    it 'returns 400 for invalid YAML payload' do
      invalid_yaml = "tag: test.ns:broken\n  - invalid"

      post '/library/api/rest/v1/tags/upload?format=yaml',
           invalid_yaml,
           { 'CONTENT_TYPE' => 'application/x-yaml' }

      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).not_to be_nil
    end

    it 'returns 400 for invalid JSON payload' do
      Tempfile.create(['tags-invalid', '.json']) do |file|
        file.write('{"tag": "broken"')
        file.rewind

        post '/library/api/rest/v1/tags/upload',
             { file: Rack::Test::UploadedFile.new(file.path, 'application/json') }
      end

      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).not_to be_nil
    end

    it 'returns 400 for empty payload' do
      post '/library/api/rest/v1/tags/upload', '', { 'CONTENT_TYPE' => 'application/x-yaml' }

      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end

    it 'returns 400 for unsupported file extension' do
      Tempfile.create(['tags', '.txt']) do |file|
        file.write("tag: test.ns:txt\nname: Unsupported\n")
        file.rewind

        post '/library/api/rest/v1/tags/upload',
             { file: Rack::Test::UploadedFile.new(file.path, 'text/plain') }
      end

      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('Unsupported upload format')
    end
  end
end
