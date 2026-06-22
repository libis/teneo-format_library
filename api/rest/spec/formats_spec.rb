# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'Formats API', type: :request do
  describe 'GET /formats' do
    it 'returns paginated list of formats' do
      get '/formats?per_page=5'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['items']).to be_an(Array)
      expect(json['items'].size).to eq(5)
      expect(json['pagination']).to include('page', 'per_page', 'total', 'total_pages')
    end

    it 'filters by source' do
      get '/formats?source=PRONOM&per_page=10'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['source']).to eq('PRONOM')
      end
    end

    it 'filters by mimetype' do
      get '/formats?mimetype=image/jpeg&per_page=10'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['mimetypes']).to include('image/jpeg')
      end
    end

    it 'filters by extension' do
      get '/formats?extension=pdf&per_page=10'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['extensions']).to include('pdf')
      end
    end

    it 'searches by query' do
      get '/formats?q=WAVE&per_page=10'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['name'].downcase).to include('wave')
      end
    end
  end

  describe 'GET /formats/search' do
    it 'requires q parameter' do
      get '/formats/search'
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end

    it 'returns search results' do
      get '/formats/search?q=Broadcast'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['items']).to be_an(Array)
      expect(json['items'].size).to be > 0
    end
  end

  describe 'GET /formats/detail' do
    it 'returns format details' do
      get '/formats/detail?uid=x-fmt/1'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['uid']).to eq('x-fmt/1')
      expect(json['name']).to eq('Microsoft Word for Macintosh Document')
      expect(json['mimetypes']).to be_an(Array)
      expect(json['extensions']).to be_an(Array)
    end

    it 'returns 400 without uid parameter' do
      get '/formats/detail'
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end

    it 'returns 404 for unknown format' do
      get '/formats/detail?uid=unknown/uid'
      expect(last_response.status).to eq(404)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('not found')
    end
  end

  describe 'GET /formats/relations' do
    it 'returns format relations' do
      get '/formats/relations?uid=x-fmt/1'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json).to be_a(Hash)
    end

    it 'filters relations by type' do
      get '/formats/relations?uid=x-fmt/1&relation_types=has_format'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json).to be_a(Hash)
    end
  end

  describe 'GET /formats/related' do
    it 'returns related formats' do
      get '/formats/related?uid=x-fmt/1'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json).to be_a(Hash)
    end
  end

  describe 'GET /formats/tags' do
    it 'returns format tags' do
      get '/formats/tags?uid=x-fmt/1'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json).to be_an(Array)
    end
  end
end
