# frozen_string_literal: true

require_relative 'base'

require 'naturally'

module Teneo
  module FormatLibrary
    class Format < Teneo::FormatLibrary::Base
      unrestrict_primary_key

      many_to_many :tags, class: Teneo::FormatLibrary::Tag, join_table: :tagged_formats, left_key: :format,
                          right_key: :tag

      # Get all the mimetypes registered for the current format
      #
      # @return [Array<string>] the list of mimetypes
      def mimetypes
        db[:mimetypes].where(format: uid).select_map(:mimetype) || []
      end

      # Set the list of mimetypes for this format
      #
      # @param mimetype_list [Array<String>] new list of mimetypes
      def mimetypes=(mimetype_list)
        db.transaction do
          db[:mimetypes].where(format: uid).delete
          [mimetype_list].flatten.each do |mimetype|
            db[:mimetypes].insert(mimetype:, format: uid)
          end
        end
      end

      # Get the list of file extensions registered for the current format
      #
      # @return [Array<String>] the list of file extensions
      def extensions
        db[:extensions].where(format: uid).select_map(:extension) || []
      end

      # Set the list of file extensions for this format
      #
      # @param extension_list [Array<String>] new list of file extensions
      def extensions=(extension_list)
        db.transaction do
          db[:extensions].where(format: uid).delete
          [extension_list].flatten.each do |extension|
            db[:extensions].insert(extension:, format: uid)
          end
        end
      end

      # Set fields like Hash
      #
      # @overrides default method that would fail on mimetypes and extensions
      def []=(key, value)
        case key
        when :mimetypes
          self.mimetypes = value
        when :extensions
          self.extensions = value
        else
          super(key, value)
        end
      end

      # Get fields like Hash
      #
      # @overrides default method that would fail on mimetypes and extensions
      def [](key)
        case key
        when :mimetypes
          mimetypes
        when :extensions
          extensions
        else
          super(key)
        end
      end

      # Get basic list of relations
      #
      # This method retrieves the relations. Besides the explicit format relations, implicit relationships that are
      # detected via mimetypes and file extensions are added.
      #
      # @return [Hash<Array,Array>] list of relations; keys are arrays with first element the relation_type and second
      # element the source (source of format information for explicit relationships or mimetype/extension for implicit
      # relationships); the values are arrays of format identifiers (uid value)
      def base_relations
        db[:format_relations]
          .where(uid: uid)
          .to_hash_groups(%i[relation_type source], :related_format)
          .merge(
            db[:mimetypes]
              .where(mimetype: mimetypes)
              .exclude(format: uid)
              .to_hash_groups(:mimetype, :format)
              .transform_keys { |x| ['same_mimetype', x] },
            db[:extensions]
              .where(extension: extensions)
              .exclude(format: uid)
              .to_hash_groups(:extension, :format)
              .transform_keys { |x| ['same_extension', x] }
          ).transform_values { |x| Naturally.sort(x) }
      end

      # Get a filtered list of relations as a Hash
      #
      # @param relation_types [Array]: only return relations with a relationship type included in the list
      # @param sources [Array]: only return relations with a source included in the list
      # @param formats [Array]: only return relations to formats in the list
      # Note: for all these parameters, the default value is an empty list which disables the filtering for that field
      #
      # @return [Hash<Array,Array>]: list of relations; same format as #basic_relations output
      def filtered_relations(relation_types: [], sources: [], formats: [])
        relation_types = [relation_types].flatten.compact.map(&:to_s)
        sources = [sources].flatten.compact.map(&:to_s)
        formats = [formats].flatten.compact.map(&:to_s)
        base_relations.select do |(rel_type, rel_source), _|
          selected(value: rel_type, filter: relation_types) &&
            selected(value: rel_source, filter: sources)
        end.each_with_object({}) do |(key, format_ids), result|
          format_ids = filter(array: format_ids, filter: formats)
          result[key] = Naturally.sort(format_ids) unless format_ids.empty?
          result
        end
      end

      # Get a processed list of relations
      #
      # Compared to the list returned from #filtered_relations, this method returns nested Hashes. The first level of
      # Hashes has the relationship type as key. Its values are also Hashes with the sources as key and a list of format
      # identifiers (uid) as value.
      #
      # @return [Hash<String, Hash<String,Array<String>>>]
      def relations(relation_types: nil, sources: nil, formats: nil)
        filtered_relations(relation_types:, sources:, formats:)
          .each_with_object({}) do |(key, format_ids), result|
            (result[key.first] ||= {})[key.last] = format_ids
          end
      end

      # Get a process list of related formats
      #
      # Compared to the list return from #relations, this method flips the data around. The top level Hash keys are the
      # formats related to this format. The keys of the nested Hash are the relationship types and values are the list
      # of sources (format info sources, mimetypes or file extensions)
      #
      # @return [Hash<String, Hash<String,Array<String>>>]
      def related_formats(relation_types: nil, sources: nil, formats: nil)
        filtered_relations(relation_types:, sources:, formats:)
          .each_with_object({}) do |(key, format_ids), result|
            format_ids.each do |format_id|
              ((result[format_id] ||= {})[key.first] ||= []) << key.last
            end
            result
          end
      end

      # Add a relation for this format
      #
      # @param related_format [String/Teneo::FormatLibrary::Format]: the other format this relation refers to
      # @param relation_type [String]: the type of relation
      # @param inverse_relation_type [String]: relation type of the inverse relationship
      #
      # Note: if no inverse_relation_type is supplied, no inverse relation will be created
      def add_relation(related_format:, relation_type:, inverse_relation_type: nil)
        related_format = related_format.uid if related_format.is_a?(Teneo::FormatLibrary::Format)
        db[:format_relations].where(
          uid: uid,
          related_format: related_format,
          relation_type: relation_type,
          source: source
        ).update(
          source_version: source_version
        ) == 1 || db[:format_relations].insert(
          uid: uid,
          related_format: related_format,
          relation_type: relation_type,
          source: source,
          source_version: source_version
        )

        return unless inverse_relation_type

        db[:format_relations].where(
          uid: related_format,
          related_format: uid,
          relation_type: inverse_relation_type,
          source: source
        ).update(
          source_version: source_version
        ) == 1 || db[:format_relations].insert(
          uid: related_format,
          related_format: uid,
          relation_type: inverse_relation_type,
          source: source,
          source_version: source_version
        )
      end

      # Returns a Hash with all tags associated with this format, directly or indirectly.
      #
      # @return [Hash<String, Teneo::FormatLibrary::Tag>] all tags associated with this format
      def all_tags_hash(namespace: nil, profile: nil)
        collected = {}
        tags.each do |tag|
          collected.merge!(tag.ancestors_hash)
        end
        collected.select do |_, tag|
          tag.matches?(namespace:, profile:)
        end
      end

      # Returns a dataset of all tags associated with this format, directly or indirectly.
      #
      # @return [Sequel::Dataset] a dataset of Tags
      def all_tags_ds(namespace: nil, profile: nil)
        namespace ||= /.*/
        profile ||= /.*/
        # Tag.where(tag: all_tags.map(&:tag))
        db[:format_tags].with_recursive(
          :format_tags,
          db[:tags].join(:tagged_formats, tag: :tag)
            .where(Sequel[:tagged_formats][:format] => uid)
            .select(Sequel.lit('tags.*')),
          db[:tags].join(:tagged_tags, parent: :tag)
            .join(:format_tags, tag: :tag)
            .select_all(:tags),
          cycle: { columns: :tag, cycle_value: true, noncycle_value: false }
        ).where(namespace:, profile:)
      end

      # Overrides the default from_hash method to handle mimetypes, extensions, and relations.
      #
      # @param data [Hash] the hash of attributes
      # @param key [Symbol, nil] an optional key for lookup existence; default: :uid
      # @param block [Proc] an optional block to execute after the format is created
      # @return [Teneo::FormatLibrary::Format] the created Format instance
      def self.from_hash(data:, key: nil, &block)
        mimetypes = data.delete(:mimetypes) || []
        extensions = data.delete(:extensions) || []
        relations = data.delete(:relations) || []
        key ||= :uid

        fmt = nil
        db.transaction do
          fmt = super(data: data, key: key, &block)

          fmt.mimetypes = mimetypes
          fmt.extensions = extensions

          relations.each do |relation|
            fmt.add_relation(
              related_format: relation[:related_format],
              relation_type: relation[:relation_type],
              inverse_relation_type: relation[:inverse_relation_type]
            )
          end
        end

        fmt
      end

      private

      def selected(value:, filter:)
        filter.empty? || filter.include?(value)
      end

      def filter(array:, filter:)
        return array if filter.empty?

        filter & array
      end
    end
  end
end
