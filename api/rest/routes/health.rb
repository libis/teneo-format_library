# frozen_string_literal: true

require_relative '../base_app'

module Routes
  class Health < BaseApp
    route do |r|
      r.get do
        { status: 'ok', timestamp: Time.now.iso8601 }
      end
    end
  end
end
