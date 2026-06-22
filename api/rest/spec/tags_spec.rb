# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'Tags API', type: :request do
  describe 'GET /tags' do
    it 'returns paginated list of tags' do
      get '/tags?per_page=5'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['items']).to be_an(Array)
      expect(json['items'].size).to eq(5)
      expect(json['pagination']).to include('page', 'per_page', 'total', 'total_pages')
    end

    it 'filters by namespace' do
      get '/tags?namespace=be.libis.teneo&per_page=10'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['namespace']).to eq('be.libis.teneo')
      end
    end

    it 'filters by profile' do
      get '/tags?profile=classification&per_page=10'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['profile']).to eq('classification')
      end
    end
  end

  describe 'GET /tags/detail' do
    it 'returns tag details' do
      get '/tags/detail?tag=be.libis.teneo:BMP'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['tag']).to eq('be.libis.teneo:BMP')
      expect(json['name']).to eq('Device Independent Bitmap (DIP/BMP) images')
      expect(json['profile']).to eq('classification')
      expect(json['namespace']).to eq('be.libis.teneo')
    end

    it 'includes formats when requested' do
      get '/tags/detail?tag=be.libis.teneo:BMP&include_formats=true'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['formats']).to be_an(Array)
      expect(json['formats'].size).to be > 0
    end

    it 'includes ancestors when requested' do
      get '/tags/detail?tag=be.libis.teneo:BMP&include_ancestors=true'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['ancestors']).to be_an(Array)
      expect(json['ancestors'].any? { |a| a['tag'] == 'be.libis.teneo:IMAGE' }).to be true
    end

    it 'includes descendants when requested' do
      get '/tags/detail?tag=be.libis.teneo:IMAGE&include_descendants=true'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['descendants']).to be_an(Array)
      expect(json['descendants'].any? { |d| d['tag'] == 'be.libis.teneo:BMP' }).to be true
    end

    it 'returns 400 without tag parameter' do
      get '/tags/detail'
      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('required')
    end

    it 'returns 404 for unknown tag' do
      get '/tags/detail?tag=unknown:tag'
      expect(last_response.status).to eq(404)
      json = JSON.parse(last_response.body)
      expect(json['error']).to include('not found')
    end
  end

  describe 'GET /tags/formats' do
    it 'returns paginated formats for tag' do
      get '/tags/formats?tag=be.libis.teneo:BMP&per_page=5'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['items']).to be_an(Array)
      expect(json['items'].size).to be <= 5
      expect(json['pagination']).to include('page', 'per_page', 'total', 'total_pages')
    end

    it 'returns formats with uid and name' do
      get '/tags/formats?tag=be.libis.teneo:BMP&per_page=3'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      json['items'].each do |item|
        expect(item['uid']).not_to be_nil
        expect(item['name']).not_to be_nil
      end
    end
  end
end
