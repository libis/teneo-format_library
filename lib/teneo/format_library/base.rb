# frozen_string_literal: true

require 'sequel'
require 'yaml'
require 'active_support/core_ext/hash/keys'

require_relative 'database'

module Teneo
  module FormatLibrary
    # Base class for all models
    #
    # This class is used as a base class for all models.
    #
    # Class Methods:
    # - from_yaml_file: Loads data from a YAML file and creates instances of the model.
    # - from_json_file: Loads data from a JSON file and creates instances of the model.
    # - from_json: Loads data from a JSON string and creates instances of the model.
    # - from_hash_: Loads data from a hash and creates instances of the model. The data does not need to be symbolized.
    # - from_hash: Loads data from a hash and creates instances of the model. The data is expected to be deeply symbolized.
    #
    # Instance Methods:
    # - stringify and pk_string: Generate a string representation of the model instance, using the class name and primary key values.
    #
    # Note that this class inherits from Sequel::Model, which provides the from_json,
    # from_hash, to_json, and to_hash methods used by the class methods.

    Base = Class.new(Sequel::Model(Teneo::FormatLibrary.db))
    Base.require_valid_table = false

    # Allows Teneo::FormatLibrary::Base to be used as a base model
    # e.g. class Foo < Teneo::FormatLibrary::Base
    Base.def_Model(self)

    class Base
      plugin :association_dependencies
      plugin :json_serializer
      plugin :csv_serializer
      plugin :update_or_create
      plugin :auto_validations
      plugin :validation_helpers
      plugin :validation_helpers_generic_type_messages
      plugin :pg_auto_constraint_validations
      plugin :uuid
      plugin :dataset_associations
      plugin :delay_add_association

      # Class methods
      class << self
        # Returns an array of volatile attributes that are not included when
        # converting to or from a hash or json. The volatile attributes are
        # attributes that are managed by the database or Sequel, and are not
        # meaningful when converting to or from a hash or json.
        def volatile_attributes
          %i[id created_at updated_at]
        end

        def from_yaml_file(file:, key: nil, &block)
          YAML.load_file(file).then do |data|
            [data].flatten.map { |d| from_hash_(data: d, key: key, &block) }
          end
        end

        def from_json_file(file:, key: nil, &block)
          from_json(data: File.read(file), key: key, &block)
        end

        def from_json(data:, key: nil, &block)
          data = JSON.parse(data)
          [data].flatten.map { |d| from_hash_(data: d, key: key, &block) }
        end

        def from_hash_(data:, key: nil, &block)
          from_hash(data: data.deep_symbolize_keys!, key:, &block)
        end

        def from_hash(data:, key: nil, &block)
          key = [key].flatten.compact.map(&:to_sym)
          pk = [primary_key].flatten
          key = pk if key.empty?
          obj = find(data.slice(*key)) || new # find or create
          data_pk = data.slice(*pk)
          data_pk.each { |k, v| obj.send("#{k}=", v) }
          data_other = data.except(*pk)
          obj.set_fields(data_other, data_other.keys)
          block.call(obj) if block_given?
          obj.save
          obj
        end
      end

      # Returns a JSON string representation of the model, excluding volatile attributes.
      #
      # @param opts [Hash] Additional options passed to the to_json method.
      # @return [String] A JSON string representation of the model.
      def to_json(**opts)
        super(except: self.class.volatile_attributes, **opts)
      end

      # Returns a hash representation of the model, excluding volatile attributes.
      #
      # @param opts [Hash] Additional options passed to the to_hash method.
      # @return [Hash] A hash representation of the model.
      def to_hash(**opts)
        super(except: self.class.volatile_attributes, **opts)
      end

      protected

      # Returns a string that uniquely identifies the instance.
      #
      # The string is composed of the class name followed by the primary key string,
      # separated by an underscore.
      #
      # @return [String] A unique string identifier for the instance.
      def stringify
        "#{self.class.name}_#{pk_string}"
      end

      # Returns a string representation of the primary key.
      #
      # The primary key is converted to a string, with multiple keys joined by an underscore.
      #
      # @return [String] A string representation of the primary key.
      def pk_string
        # [pk].flatten is required because pk can be a simple value or an array
        [pk].flatten.map(&:to_s).join('_')
      end
    end
  end
end
