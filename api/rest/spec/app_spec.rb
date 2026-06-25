# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'API', type: :request do
  describe 'GET /library/api/rest/v1' do
    it 'returns API info' do
      get '/library/api/rest/v1'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['message']).to eq('Teneo Format Library API')
      expect(json['version']).to eq(Teneo::FormatLibrary::VERSION)
    end
  end

  describe 'GET /library/api/rest/v1/health', type: :request do
    it 'returns health status' do
      get '/library/api/rest/v1/health'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['status']).to eq('ok')
      expect(json['timestamp']).not_to be_nil
    end
  end

  describe 'GET /library/api/rest/v1/doc', type: :request do
    it 'serves the documentation index page' do
      get '/library/api/rest/v1/doc'
      expect(last_response).to be_ok
      expect(last_response.headers['Content-Type']).to include('text/html')
      expect(last_response.body).to include('<!DOCTYPE html>')
    end
  end

  describe 'GET /library/api/rest/v1/doc/bundle.css', type: :request do
    it 'serves static documentation assets' do
      get '/library/api/rest/v1/doc/bundle.css'
      expect(last_response).to be_ok
      expect(last_response.headers['Content-Type']).to include('text/css')
      expect(last_response.body).not_to be_empty
    end
  end
end
