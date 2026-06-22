# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'API', type: :request do
  describe 'GET /' do
    it 'returns API info' do
      get '/'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['message']).to eq('Teneo Format Library API')
      expect(json['version']).to eq(Teneo::FormatLibrary::VERSION)
    end
  end

  describe 'GET /health', type: :request do
    it 'returns health status' do
      get '/health'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['status']).to eq('ok')
      expect(json['timestamp']).not_to be_nil
    end
  end
end
