# frozen_string_literal: true

module Routes
  class Health < Roda
    route do |r|
      r.get do
        response['Content-Type'] = 'application/json'
        { status: 'ok', timestamp: Time.now.iso8601 }.to_json
      end
    end
  end
end