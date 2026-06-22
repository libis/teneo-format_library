# frozen_string_literal: true

require 'grpc'
require 'teneo/format_library'

require_relative 'service/health_service'
require_relative 'service/format_service'
require_relative 'service/tag_service'

module Teneo
  module FormatLibrary
    module V1
      class GRPCServer
        def self.run(port: 50_051)
          server = GRPC::RpcServer.new
          server.add_http2_port("0.0.0.0:#{port}", :this_port_is_insecure)
          server.handle(HealthService.new)
          server.handle(FormatService.new)
          server.handle(TagService.new)

          puts "gRPC server running on port #{port}"
          server.run_till_terminated_or_interrupted([1, 'int', 'SIGTERM'])
        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  port = ENV['GRPC_PORT']&.to_i || 50_051
  Teneo::FormatLibrary::V1::GRPCServer.run(port: port)
end
