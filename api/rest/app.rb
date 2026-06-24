# frozen_string_literal: true

require 'roda'
require 'json'
require 'teneo/format_library'

require_relative 'routes/health'
require_relative 'routes/formats'
require_relative 'routes/tags'

class App < Roda
  plugin :json
  plugin :json_parser
  plugin :all_verbs
  plugin :request_headers
  plugin :halt

  route do |r|
    r.on 'library' do
      r.on 'api' do
        r.on 'rest' do
          r.on 'v1' do
            r.is do
              response['Content-Type'] = 'application/json'
              { message: 'Teneo Format Library API', version: Teneo::FormatLibrary::VERSION }.to_json
            end

            r.on 'health' do
              r.run Routes::Health
            end

            r.on 'formats' do
              r.run Routes::Formats
            end

            r.on 'tags' do
              r.run Routes::Tags
            end

            r.on 'openapi' do
              r.get 'json' do
                response['Content-Type'] = 'application/json'
                File.read(File.join(__dir__, 'doc', 'openapi.json'))
              end

              r.get 'yaml' do
                response['Content-Type'] = 'application/yaml'
                File.read(File.join(__dir__, 'doc', 'openapi.yaml'))
              end
            end
          end
        end
      end
    end
  end
end
