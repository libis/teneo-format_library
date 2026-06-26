# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'API', openapi: { tags: ['API'], example_mode: :none }, type: :request do
  describe 'GET /library/api/rest/v1', openapi: { summary: 'Get API info' } do
    it 'returns API info' do
      get '/library/api/rest/v1'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['message']).to eq('Teneo Format Library API')
      expect(json['version']).to eq(Teneo::FormatLibrary::VERSION)
    end
  end

  describe 'GET /library/api/rest/v1/health', openapi: { summary: 'Get API health status' }, type: :request do
    it 'returns health status' do
      get '/library/api/rest/v1/health'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['status']).to eq('ok')
      expect(json['timestamp']).not_to be_nil
    end
  end

  describe 'GET /library/api/rest/v1/doc/index.html', openapi: false, type: :request do
    it 'serves the documentation index page' do
      get '/library/api/rest/v1/doc/index.html'
      expect(last_response).to be_ok
      expect(last_response.headers['Content-Type']).to include('text/html')
      expect(last_response.body).to include('<!DOCTYPE html>')
    end
  end

  describe 'GET /library/api/rest/v1/doc', openapi: false, type: :request do
    it 'serves the documentation index page' do
      get '/library/api/rest/v1/doc'
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_request.path).to eq('/library/api/rest/v1/doc/index.html')
      expect(last_response).to be_ok
      expect(last_response.headers['Content-Type']).to include('text/html')
      expect(last_response.body).to include('<!DOCTYPE html>')
    end
  end

  describe 'GET /library/api/rest/v1/doc/bundle.css', openapi: false, type: :request do
    it 'serves static documentation assets' do
      get '/library/api/rest/v1/doc/bundle.css'
      expect(last_response).to be_ok
      expect(last_response.headers['Content-Type']).to include('text/css')
      expect(last_response.body).not_to be_empty
    end
  end

  describe 'GET /library/api/rest/v1/doc/:file', openapi: false, type: :request do
    it 'returns 404 when doc file does not exist' do
      get '/library/api/rest/v1/doc/does-not-exist.js'
      expect(last_response.status).to eq(404)
      json = JSON.parse(last_response.body)
      expect(json['error']).to eq('Document not found')
    end
  end
end
