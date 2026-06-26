# frozen_string_literal: true

require_relative 'spec_helper'
require 'securerandom'
require 'tempfile'

RSpec.describe 'Tags API', openapi: { tags: ['Tags'] }, type: :request do
  def build_payload(flag = 'test')
    {
      tag: "test:test-tag-#{flag || 'test' }",
      name: 'Test Tag',
      profile: 'TEST',
      properties: {},
      info: {}
    }
  end

  def build_format_payload
    {
      uid: 'test-format-test',
      name: 'Test Format',
      source: 'TEST',
      mimetypes: ['application/test'],
      extensions: ['.test']
    }
  end

  before(:example, with_payload: true) do
    @payload = build_payload
  end

  before(:example, with_tag: true) do
    @payload = build_payload
    @payload_parent = build_payload('parent')
    @payload_child = build_payload('child')
    @tag = Teneo::FormatLibrary::Tag.from_hash_(data: @payload.transform_keys(&:to_s))
    @parent_tag = Teneo::FormatLibrary::Tag.from_hash_(data: @payload_parent.transform_keys(&:to_s))
    @child_tag = Teneo::FormatLibrary::Tag.from_hash_(data: @payload_child.transform_keys(&:to_s))
    @format_payload = build_format_payload
    @format = Teneo::FormatLibrary::Format.from_hash_(data: @format_payload.transform_keys(&:to_s))
    @tag.add_format @format
    @tag.add_child_tag @child_tag
    @parent_tag.add_child_tag @tag
  end

  after(:example) do
    Teneo::FormatLibrary::Format[@format_payload&.fetch(:uid)]&.destroy
    Teneo::FormatLibrary::Tag[@payload_child&.fetch(:tag)]&.destroy
    Teneo::FormatLibrary::Tag[@payload&.fetch(:tag)]&.destroy
    Teneo::FormatLibrary::Tag[@payload_parent&.fetch(:tag)]&.destroy
  end

  describe 'GET /library/api/rest/v1/tags', openapi: { summary: 'Get a list of tags' } do
    it 'returns paginated list of tags' do
      get '/library/api/rest/v1/tags?per_page=2'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['items']).to be_an(Array)
      expect(json['items'].size).to eq(2)
      expect(json['pagination']).to include('page', 'per_page', 'total', 'total_pages')
    end

    it 'filters by namespace', with_tag: true do
      get "/library/api/rest/v1/tags?namespace=#{@tag.namespace}&per_page=2"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['tag']).to start_with("#{@tag[:namespace]}:")
      end
    end

    it 'filters by profile', with_tag: true do
      get "/library/api/rest/v1/tags?profile=#{@tag[:profile]}&per_page=2"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['profile']).to eq(@tag[:profile])
      end
    end
  end

  describe 'GET /library/api/rest/v1/tags/detail', openapi: { summary: 'Get tag details', example_mode: { request: :multiple, response: :single} } do
    it 'returns tag details', with_tag: true do
      get "/library/api/rest/v1/tags/detail?tag=#{@tag.tag}"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['tag']).to eq(@tag.tag)
      expect(json['name']).to eq(@tag.name)
      expect(json['profile']).to eq(@tag.profile)
    end

    it 'includes formats when requested', with_tag: true do
      get "/library/api/rest/v1/tags/detail?tag=#{@tag.tag}&include_formats=true"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['formats']).to be_an(Array)
      expect(json['formats'].size).to be > 0
      expect(json['formats'].any? { |f| f['uid'] == @format.uid }).to be true
    end

    it 'includes ancestors when requested', with_tag: true do
      get "/library/api/rest/v1/tags/detail?tag=#{@tag.tag}&include_ancestors=true"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['ancestors']).to be_an(Array)
      expect(json['ancestors'].any? { |a| a['tag'] == @parent_tag.tag }).to be true
    end

    it 'includes descendants when requested', with_tag: true do
      get "/library/api/rest/v1/tags/detail?tag=#{@tag.tag}&include_descendants=true"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['descendants']).to be_an(Array)
      expect(json['descendants'].any? { |d| d['tag'] == @child_tag.tag }).to be true
    end

    it 'can include ancestors, descendants and formats', with_tag: true do
      get "/library/api/rest/v1/tags/detail?tag=#{@tag.tag}&include_ancestors=true&include_descendants=true&include_formats=true"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['ancestors']).to be_an(Array)
      expect(json['ancestors'].any? { |a| a['tag'] == @parent_tag.tag }).to be true
      expect(json['descendants']).to be_an(Array)
      expect(json['descendants'].any? { |d| d['tag'] == @child_tag.tag }).to be true
      expect(json['formats']).to be_an(Array)
      expect(json['formats'].size).to be > 0
      expect(json['formats'].any? { |f| f['uid'] == @format.uid }).to be true
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

  describe 'POST /library/api/rest/v1/tags', openapi: { summary: 'Create a new tag' } do
    it 'creates a new tag', with_payload: true do
      post '/library/api/rest/v1/tags', @payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['tag']).to eq(@payload[:tag])
      expect(json['name']).to eq(@payload[:name])
      expect(json['profile']).to eq(@payload[:profile])
    end

    it 'returns 400 for invalid payload' do
      post '/library/api/rest/v1/tags', { name: 'Missing tag' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).not_to be_nil
    end
    it 'returns 400 if tag exists', with_tag: true do
      post '/library/api/rest/v1/tags', @payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).not_to be_nil
    end
  end

  describe 'PUT /library/api/rest/v1/tags/detail', openapi: { summary: 'Update an existing tag' } do
    it 'updates an existing tag', with_tag: true do
      update_payload = { tag: @tag.tag, name: 'Updated Name' }
      put "/library/api/rest/v1/tags/detail?tag=#{@tag.tag}", update_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['tag']).to eq(@tag.tag)
      expect(json['name']).to eq('Updated Name')
    end

    it 'returns 400 without tag parameter' do
      put '/library/api/rest/v1/tags/detail', { name: 'Updated Name' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end

    it 'returns 404 for unknown tag' do
      put '/library/api/rest/v1/tags/detail?tag=unknown:tag', { name: 'Updated Name' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(404)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('not found')
    end
  end

  describe 'DELETE /library/api/rest/v1/tags/detail', openapi: { summary: 'Delete an existing tag' } do
    it 'deletes an existing tag', with_tag: true do
      delete "/library/api/rest/v1/tags/detail?tag=#{@payload[:tag]}"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['deleted']).to eq(@payload[:tag])

      tag = Teneo::FormatLibrary::Tag[@payload[:tag]]
      expect(tag).to be_nil
    end

    it 'returns 400 without tag parameter' do
      delete '/library/api/rest/v1/tags/detail'
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end

    it 'returns 404 for unknown tag' do
      delete '/library/api/rest/v1/tags/detail?tag=unknown:tag'
      expect(last_response.status).to eq(404)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('not found')
    end
  end

  describe 'GET /library/api/rest/v1/tags/formats', openapi: { summary: 'Get formats for a tag' } do
    it 'returns paginated formats for tag', with_tag: true do
      get "/library/api/rest/v1/tags/formats?tag=#{@payload[:tag]}&per_page=2"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['items']).to be_an(Array)
      expect(json['items'].size).to be <= 2
      expect(json['pagination']).to include('page', 'per_page', 'total', 'total_pages')
    end

    it 'returns formats with uid and name', with_tag: true do
      get "/library/api/rest/v1/tags/formats?tag=#{@payload[:tag]}&per_page=3"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['uid']).not_to be_nil
        expect(item['name']).not_to be_nil
      end
    end

    it 'returns 400 without tag parameter' do
      get '/library/api/rest/v1/tags/formats'
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end

    it 'returns 404 for unknown tag' do
      get '/library/api/rest/v1/tags/formats?tag=unknown:tag'
      expect(last_response.status).to eq(404)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('not found')
    end
  end

  describe 'GET /library/api/rest/v1/tags/tree', openapi: { summary: 'Get tag tree structure' } do
    it 'returns tree structure for tag', with_tag: true do
      get "/library/api/rest/v1/tags/tree?tag=#{@payload[:tag]}"
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json).to be_a(Hash)
    end

    it 'returns 400 without tag parameter' do
      get '/library/api/rest/v1/tags/tree'
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end

    it 'returns 404 for unknown tag' do
      get '/library/api/rest/v1/tags/tree?tag=unknown:tag'
      expect(last_response.status).to eq(404)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('not found')
    end
  end

  describe 'POST /library/api/rest/v1/tags/upload', openapi: {
    summary: 'Upload tags from a file',
    example_mode: :none,
    enum: {
      format: %w[yaml json]
    }
  } do
    it 'uploads tags from YAML file', with_payload: true do
      yaml = <<~YAML
        - tag: #{@payload[:tag]}
          name: #{@payload[:name]}
          profile: #{@payload[:profile]}
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
      expect(json['items'].first['tag']).to eq(@payload[:tag])
      expect(json['items'].first['name']).to eq(@payload[:name])
      expect(json['items'].first['profile']).to eq(@payload[:profile])

      tag = Teneo::FormatLibrary::Tag[@payload[:tag]]
      expect(tag).not_to be_nil
      expect(tag.name).to eq(@payload[:name])
      expect(tag.profile).to eq(@payload[:profile])
    end

    it 'uploads tags from JSON file', with_payload: true do
      payload = [@payload]
      Tempfile.create(['tags', '.json']) do |file|
        file.write(payload.to_json)
        file.rewind

        post '/library/api/rest/v1/tags/upload',
             { file: Rack::Test::UploadedFile.new(file.path, 'application/json') }
      end

      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['count']).to eq(1)
      expect(json['items'].first['tag']).to eq(@payload[:tag])
      expect(json['items'].first['name']).to eq(@payload[:name])
      expect(json['items'].first['profile']).to eq(@payload[:profile])

      tag = Teneo::FormatLibrary::Tag[@payload[:tag]]
      expect(tag).not_to be_nil
      expect(tag.name).to eq(@payload[:name])
      expect(tag.profile).to eq(@payload[:profile])
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
