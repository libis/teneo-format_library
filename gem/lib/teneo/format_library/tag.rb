# frozen_string_literal: true

require_relative 'base'
require 'active_support/core_ext/object/blank'

module Teneo
  module FormatLibrary
    class Tag < Teneo::FormatLibrary::Base
      many_to_many :formats, class: Teneo::FormatLibrary::Format, join_table: :tagged_formats, left_key: :tag, right_key: :format
      many_to_many :child_tags, class: self, join_table: :tagged_tags, left_key: :parent, right_key: :tag
      many_to_many :parent_tags, class: self, join_table: :tagged_tags, left_key: :tag, right_key: :parent

      dataset_module do
        # Finds all tags in a certain namespace.
        #
        # @param namespace [String|Regexp] the namespace of the tags to find
        # @return [Sequel::Dataset] a dataset with all tags with the given namespace
        def with_namespace(namespace = nil)
          namespace ||= /.*/
          where(namespace:)
        end

        # Finds all tags with a certain profile.
        #
        # @param profile [String|Regexp] the profile of the tags to find
        # @return [Sequel::Dataset] a dataset with all tags with the given profile
        def with_profile(profile = nil)
          profile ||= /.*/
          where(profile:)
        end
      end

      # Creates a Hash of tags that are descendants of this tag.
      #
      # @param collected [Set<Teneo::FormatLibrary::Tag>] a set of tags to avoid an infinite loop
      # @return [Hash<String, Teneo::FormatLibrary::Tag>] all descendant tags of this tag
      def descendants_hash(collected: {}, namespace: nil, profile: nil)
        return collected if collected.key?(tag)

        collected[tag] = self
        child_tags.each do |child|
          next if collected.key(child.tag)

          # collected.merge!(child.descendants_hash(collected))
          child.descendants_hash(collected:)
        end
        collected.select do |_, tag|
          tag.matches?(namespace:, profile:)
        end
      end

      # Creates a Hash of tags that are ancestors of this tag.
      #
      # @param collected [Set<Teneo::FormatLibrary::Tag>] a set of tags to avoid an infinite loop
      # @return [Hash<String, Teneo::FormatLibrary::Tag>] all ancestor tags of this tag
      def ancestors_hash(collected: {}, namespace: nil, profile: nil)
        return collected if collected.key?(tag)

        collected[tag] = self
        parent_tags.each do |parent|
          next if collected.key?(parent.tag)

          # collected.merge!(parent.ancestors_hash(collected))
          parent.ancestors_hash(collected:)
        end
        collected.select do |_, tag|
          tag.matches?(namespace:, profile:)
        end
      end

      # Returns a dataset of all descendant tags of this tag.
      #
      # @return [Sequel::Dataset] A dataset of Tags.
      def descendants_ds(namespace: nil, profile: nil)
        namespace ||= /.*/
        namespace = /^#{namespace}/ if namespace.is_a?(String)
        profile ||= /.*/
        db[:child_tags].with_recursive(
          :child_tags,
          db[:tags].where(tag: tag),
          db[:tags]
            .join(:tagged_tags, tag: :tag)
            .join(:child_tags, tag: :parent)
            .select_all(:tags),
          cycle: { columns: :tag, cycle_value: true, noncycle_value: false }
        ).where(tag: namespace, profile:)
      end

      # Returns a dataset of all ancestor tags of this tag.
      #
      # @return [Sequel::Dataset] A dataset of Tags.
      def ancestors_ds(namespace: nil, profile: nil)
        namespace ||= /.*/
        namespace = /^#{namespace}/ if namespace.is_a?(String)
        profile ||= /.*/
        db[:parent_tags]
          .with_recursive(
            :parent_tags,
            db[:tags].where(tag: tag),
            db[:tags]
              .join(:tagged_tags, parent: :tag)
              .join(:parent_tags, tag: :tag)
              .select_all(:tags),
            cycle: { columns: :tag, cycle_value: true, noncycle_value: false }
          ).where(tag: namespace, profile:)
      end

      # Returns a dataset of the tree of tag descendants
      #
      # @return [Sequel::Dataset] A dataset with {tag:, parent:} pairs.
      def tree_ds
        db[:tag_tree]
          .with_recursive(
            :tag_tree,
            db[:tags].where(tag: tag).select(:tag, Sequel[nil].as(:parent)),
            db[:tagged_tags].join(:tag_tree, tag: :parent)
              .select(Sequel[:tagged_tags][:tag], Sequel[:tagged_tags][:parent]),
            cycle: { columns: :tag, cycle_value: true, noncycle_value: false }
          )
      end

      def tree_list
        tree_ds.to_hash(:path).keys
      end

      # Builds a nested hash structure from the tag tree.
      #
      # @return [DeepHash] a nested hash structure representing the tag tree.
      def tree_structure
        tree_ds.each_with_object(DeepHash.new) do |row, hash|
          # Skip the root node
          if row[:parent].nil?
            hash[row[:tag]] ||= DeepHash.new
            next
          end
          *path, node = row[:path].gsub(/[{}()]/, '').split(',')
          hash.dig(*path)[node] ||= DeepHash.new
        end.clear_empty
      end

      # Builds a nested hash structure from the tag tree with formats.
      #
      # This method is similar to {#tree_structure}, but it adds a `formats` key to each
      # node in the tree, with a hash of associated formats. The hash is keyed by format
      # UID and has the format as the value. If a node has no associated formats, the
      # `formats` key is not included.
      #
      # @return [DeepHash] a nested hash structure representing the tag tree with formats.
      def tree_formats
        tree_structure.transform do |tag, children|
          r = DeepHash.new
          r[:tags] = children if children.present?
          r[:formats] = Tag.find(tag: tag)&.formats&.each_with_object(DeepHash.new) do |format, h|
            h[format.uid] = format
          end
          r.clear_empty.compact
        end
      end

      # Returns a hash with all formats that are associated with this tag or any of its
      # descendant tags. The hash is keyed by format UID and has the format as the value.
      def all_formats_hash
        descendants_hash.each_with_object({}) do |(_, tag), collected|
          tag.formats.each do |format|
            collected[format.uid] = format
          end
        end
      end

      # Returns a dataset of all formats that are associated with this tag or any of its
      # descendant tags.
      #
      # @return [Sequel::Dataset] A dataset of Formats.
      def all_formats_ds
        db[:formats]
          .join(:tagged_formats, format: :uid)
          .where(Sequel[:tagged_formats][:tag] => descendants_ds.select(:tag))
      end

      # Create tag from hash
      #
      # @overrides Base#from_hash
      def self.from_hash(data:, key: nil, &block)
        # extract list of formats and related tags
        formats = data.delete(:formats)
        tags = data.delete(:tags)
        children = data.delete(:children)

        tag = super data:, key:, &block

        link_formats_to_tag(tag:, formats:) if formats.present?
        link_tags_to_tag(tag:, tags:) if tags.present?
        link_child_tags_to_tag(tag:, children:, key:, &block) if children.present?

        tag
      end

      def self.link_formats_to_tag(tag:, formats:)
        # Remove all existing links between the tag and the formats.
        tag.remove_all_formats

        # List of formats can be a single string
        formats = formats.split(/[\s,]+/) if formats.is_a? String

        # Add the formats to the tag from list of formats (only uid)
        [formats].flatten.compact.map(&:strip).each do |uid|
          format = Teneo::FormatLibrary::Format.find(uid: uid.strip)
          raise "Format '#{uid}' not found" unless format

          tag.add_format format
        end
      end

      def self.link_tags_to_tag(tag:, tags:)
        # Remove all existing links between the tag and other tags.
        db[:tagged_tags].where(tag: tag.tag).delete

        # tags can be a single string
        tags = tags.split(/[\s,]+/) if tags.is_a? String

        # Add the tags to the tag from the list of tags (only tag)
        [tags].flatten.compact.map(&:strip).each do |child_tag|
          child = Teneo::FormatLibrary::Tag.find(tag: child_tag)
          raise "Tag '#{child_tag}' not found" unless child

          tag.add_child_tag child
        end
      end

      def self.link_child_tags_to_tag(tag:, children:, key:, &block)
        # Create a new tag with the given UID and name.

        # from children (entire tag definition)
        children&.each do |data|
          child = Teneo::FormatLibrary::Tag.from_hash(data:, key:, &block)
          raise "Tag '#{data[:tag]}' not found" unless child

          tag.add_child_tag child
        end
      end

      def matches?(namespace: nil, profile: nil)
        case namespace
        when nil
          true
        when String
          tag == namespace
        when Regexp
          tag =~ namespace
        else
          false
        end &&
          case profile
          when nil
            true
          when String
            self.profile == profile
          when Regexp
            self.profile =~ profile
          else
            false
          end
      end

      class DeepHash < Hash
        # Remove any empty hashes from the tree.
        def clear_empty
          each do |k, v|
            if v.is_a?(DeepHash)
              if v.empty?
                self[k] = nil
              else
                v.clear_empty
              end
            end
          end
        end

        # Recursively applies the given block to each key-value pair in the hash.
        # If the value is itself a hash, the block is applied recursively.
        # The return values of the block are used to build a new hash.
        def transform(&block)
          each_with_object(DeepHash.new) do |(k, v), h|
            v = v.transform(&block) if v.is_a?(DeepHash)
            h[k] = block.call(k, v)
          end
        end
      end
    end
  end
end
