# frozen_string_literal: true

require 'roda'
require 'json'

class BaseApp < Roda
  plugin :json
  plugin :json_parser
  plugin :all_verbs
  plugin :request_headers
  plugin :halt
  plugin :default_headers,
         'Content-Type' => 'application/json',
         'Allow-Origin' => '*',
         'Access-Control-Allow-Origin' => '*',
         'Access-Control-Allow-Methods' => 'GET, POST, PUT, DELETE, OPTIONS',
         'Access-Control-Allow-Headers' => '*'
end
