# frozen_string_literal: true

require 'teneo/format_library'

require_relative 'base_app'

require_relative 'routes/health'
require_relative 'routes/formats'
require_relative 'routes/tags'
require_relative 'routes/doc'

class App < BaseApp
  route do |r|
    r.on 'library' do
      r.on 'api' do
        r.on 'rest' do
          r.on 'v1' do
            r.is do
              { message: 'Teneo Format Library API', version: Teneo::FormatLibrary::VERSION }
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

            r.on 'doc' do
              r.run Routes::Doc
            end

            r.on 'openapi' do
              r.get 'json' do
                response['Content-Type'] = 'application/json'
                response['Content-Disposition'] = 'attachment; filename="openapi.json"'
                File.read(File.join(__dir__, 'doc', 'openapi.json'))
              end

              r.get 'yaml' do
                response['Content-Type'] = 'application/yaml'
                response['Content-Disposition'] = 'attachment; filename="openapi.yaml"'
                File.read(File.join(__dir__, 'doc', 'openapi.yaml'))
              end
            end
          end
        end
      end
    end
  end
end
