# frozen_string_literal: true

ENV['DB_HOST'] ||= 'localhost'
ENV['DB_PORT'] ||= '5432'
ENV['DB_NAME'] ||= 'teneo'
ENV['DB_USER'] ||= 'teneo'
ENV['DB_PASSWORD'] ||= 'teneo'
ENV['DB_ADAPTER'] ||= 'postgresql'

require 'teneo/format_library'
Teneo::FormatLibrary::Database.config(
  host: ENV['DB_HOST'],
  port: ENV['DB_PORT'].to_i,
  database: ENV['DB_NAME'],
  user: ENV['DB_USER'],
  password: ENV['DB_PASSWORD'],
  adapter: ENV['DB_ADAPTER'].to_sym
)
Teneo::FormatLibrary::Database.reconnect

require 'rspec/openapi'

RSpec::OpenAPI.path = "doc/openapi.#{ENV['OPENAPI_FORMAT'] || 'yaml'}"

require_relative '../app'
require 'rack/test'

RSpec.configure do |config|
  config.include Rack::Test::Methods

  def app
    App
  end
end
