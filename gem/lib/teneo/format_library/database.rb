# frozen_string_literal: true

require 'dotenv'
Dotenv.load('.env.local', '.env')

require 'singleton'

require 'sequel'

module Teneo
  module FormatLibrary
    # The Database class is a singleton that manages a connection to a database using the Sequel gem.
    #
    # It provides methods for connecting, reconnecting, and disconnecting from the database,
    # as well as configuring the connection settings.
    #
    # Class Methods
    # - connect: Connects to the database using the current configuration.
    # - reconnect(**opts): Reconfigures the database connection with the provided options and reconnects to the database.
    #
    # Instance Methods
    # - config(**opts): Configures the database connection settings with the provided options.
    # - connect: Establishes a connection to the database using the current configuration.
    # - disconnect: Disconnects from the current database connection if it is valid.
    # - reconnect: Disconnects from the current database connection, resets the connection, and reconnects.
    class Database
      include Singleton

      # Connects to the database using the current configuration.
      def self.connect
        instance.connect
      end

      # Reconfigures the database connection with the provided options and reconnects to the database.
      def self.reconnect(**opts)
        instance.config(**opts)
        instance.reconnect
      end

      # Disconnects from the current database connection if it is valid, resets the connection, and
      # reconnects to the database using the current configuration.
      def reconnect
        disconnect
        @db = nil
        connect
      end

      # Establishes a connection to the database using the current configuration.
      #
      # When the :debug logging level is enabled, sets the SQL log level to :debug and
      # logs all queries to a logger that outputs to $stdout.
      def connect
        @db ||= Sequel.connect(
          adapter: adapter,
          user: user,
          password: password,
          host: host,
          port: port,
          ssl_mode: 'prefer',
          database: database,
          max_connections: max_connections,
          extensions: extensions
        ) do |database|
          database.stream_all_queries = true
          database.sql_log_level = :debug if ENV['LOGGING']&.downcase == 'debug'
          database
        end
      end

      def self.config(**opts)
        instance.config(**opts)
      end

      # Configures the database connection settings with the provided options.
      #
      # The options available are:
      # - adapter: The database adapter to use.
      # - user: The database user to connect as.
      # - password: The password to use for the database user.
      # - database: The name of the database to connect to.
      # - host: The hostname or IP address of the database host.
      # - port: The port number to use for the database connection.
      # - max_connections: The maximum number of connections to allow in the connection pool.
      # - extensions: An array of extensions to enable for the database connection.
      def config(**opts)
        (opts || {}).each do |key, value|
          case key
          when :adapter
            @adapter = value
          when :user
            @user = value
          when :password
            @password = value
          when :database
            @database = value
          when :host
            @host = value
          when :port
            @port = value
          when :max_connections
            @max_connections = value
          when :extensions
            value = value.split(/[\t, ]+/) if value.is_a?(String)
            @extensions += [value].flatten.compact.map(&:to_sym)
          end
        end
      end

      def adapter
        @adapter ||= ENV.fetch('DB_ADAPTER', :postgres).to_sym
      end

      def user
        @user ||= ENV.fetch('DB_USER', 'teneo')
      end

      def password
        @password ||= ENV.fetch('DB_PASSWORD', 'teneo')
      end

      def database
        @database ||= ENV.fetch('DB_NAME', 'teneo')
      end

      def host
        @host ||= ENV.fetch('DB_HOST', 'localhost')
      end

      def port
        @port ||= ENV.fetch('DB_PORT', 5432).to_i
      end

      def max_connections
        @max_connections ||= ENV.fetch('DB_MAX_CONNECTIONS', 10).to_i
      end

      def extensions
        @extensions ||= %i[async_thread_pool pg_array pg_json pg_streaming pg_auto_parameterize]
      end

      def db
        connect
      end

      # Disconnects from the current database connection if it is valid.
      #
      # @return [Boolean] True if the connection was valid and disconnected, false otherwise.
      def disconnect
        return unless @db.is_a?(Sequel::Database)

        begin
          return unless @db.valid_connection?
        rescue ArgumentError
          # Sequel 5.105+ requires argument for valid_connection?
          # If it fails, assume connection is valid and try to disconnect
        end

        @db.disconnect
      end

      private

      # Delegate any undefined method call to the underlying Sequel::Database instance.
      #
      # @param method [Symbol] The method name.
      # @param args [Array] The array of arguments.
      # @param block [Proc] The optional block.
      def method_missing(method, *args, &block)
        @db.send(method, *args, &block)
      end

      # Determines if a method should be handled by method_missing.
      #
      # This method checks if the underlying Sequel::Database instance
      # can respond to the given method. If so, it returns true, indicating
      # that method_missing should handle the method. Otherwise, it defers
      # to the superclass's implementation.
      #
      # @param method [Symbol] The method name to check.
      # @param include_private [Boolean] Whether to include private methods in the check.
      # @return [Boolean] True if the method can be handled by method_missing, false otherwise.
      def respond_to_missing?(method, include_private = false)
        @db.respond_to?(method, include_private) || super
      end
    end
  end
end
