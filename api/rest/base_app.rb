# frozen_string_literal: true

require 'roda'
require 'json'

class BaseApp < Roda
  plugin :json
  plugin :json_parser
  plugin :all_verbs
  plugin :request_headers
  plugin :halt
end
