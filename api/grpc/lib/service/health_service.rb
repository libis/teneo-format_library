# frozen_string_literal: true

require_relative 'format_library_services_pb'
require 'teneo/format_library'

module Teneo
  module FormatLibrary
    module V1
      class HealthService < Teneo::FormatLibrary::V1::HealthService::Service
        def check(_request, _call)
          Teneo::FormatLibrary::V1::HealthCheckResponse.new(
            status: 'ok',
            timestamp: Time.now.iso8601
          )
        end
      end
    end
  end
end
