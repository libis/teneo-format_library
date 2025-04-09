# frozen_string_literal: true

require_relative 'base'

module Teneo
  module FormatLibrary
    class Tag < Teneo::FormatLibrary::Base
      plugin :optimistic_locking

      many_to_many :formats, class: Teneo::FormatLibrary::Format, join_table: :tagged_formats, left_key: :tag, right_key: :format
      many_to_many :child_tags, class: self, join_table: :tagged_tags, left_key: :parent, right_key: :tag
      many_to_many :parent_tags, class: self, join_table: :tagged_tags, left_key: :tag, right_key: :parent

      dataset_module do
        # Finds all tags with a certain profile.
        #
        # @param profile [String] the profile of the tags to find
        # @return [Sequel::Dataset] a dataset with all tags with the given profile
        def with_profile(profile:)
          profile ||= /.*/
          where(profile: profile)
        end
      end

      # Creates a Hash of tags that are descendants of this tag.
      #
      # @param collected [Set<Teneo::FormatLibrary::Tag>] a set of tags to avoid an infinite loop
      # @return [Hash<String, Teneo::FormatLibrary::Tag>] all descendant tags of this tag
      def descendants_hash
        collected = { tag => self }
        child_tags.each do |child|
          next if collected.include?(child)

          # collected[child.tag] = child
          collected.merge!(child.descendants_hash)
        end
        collected
      end

      # Creates a Hash of tags that are ancestors of this tag.
      #
      # @param collected [Set<Teneo::FormatLibrary::Tag>] a set of tags to avoid an infinite loop
      # @return [Hash<String, Teneo::FormatLibrary::Tag>] all ancestor tags of this tag
      def ancestors_hash
        collected = { tag => self }
        parent_tags.each do |parent|
          next if collected.include?(parent)

          # collected[parent.tag] = parent
          collected.merge!(parent.ancestors_hash)
        end
        collected
      end

      # Returns a dataset of all descendant tags of this tag.
      #
      # @return [Sequel::Dataset] A dataset of Tags.
      def descendants_ds
        db[:child_tags]
          .with_recursive(
            :child_tags,
            db[:tags].where(tag: tag),
            db[:tags]
              .join(:tagged_tags, tag: :tag)
              .join(:child_tags, tag: :parent)
              .select(Sequel.lit('tags.*'))
          )
      end

      # Returns a dataset of all ancestor tags of this tag.
      #
      # @return [Sequel::Dataset] A dataset of Tags.
      def ancestors_ds
        db[:parent_tags]
          .with_recursive(
            :parent_tags,
            db[:tags].where(tag: tag),
            db[:tags]
              .join(:tagged_tags, parent: :tag)
              .join(:parent_tags, tag: :tag)
              .select(Sequel.lit('tags.*'))
          )
      end

      # Returns a dataset of the tree of tag descendants
      #
      # @return [Sequel::Dataset] A dataset with {tag:, parent:} pairs.
      def tree
        db[:tag_tree]
          .with_recursive(
            :tag_tree,
            db[:tagged_tags].where(parent: tag).select(:tag, :parent),
            db[:tagged_tags].join(:tag_tree, tag: :parent)
              .select(Sequel[:tagged_tags][:tag], Sequel[:tagged_tags][:parent])
          )
      end

      # Builds a nested hash structure from the tag tree.
      #
      # @return [DeepHash] a nested hash structure representing the tag tree.
      def tree_structure
        tree_hash = DeepHash.new
        tree.each do |row|
          r = tree_hash.deep_find(row[:parent])
          if r
            r[row[:tag]] ||= DeepHash.new
          else
            tree_hash[row[:parent]] = DeepHash[row[:tag], DeepHash.new]
          end
        end
        tree_hash.clear_empty
      end

      def tree_formats
        tree_structure.transform do |tag, children|
          r = DeepHash.new
          r[:tags] = children unless children&.empty?
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

      def self.from_hash(data:, key: nil, &block)
        children = data.delete(:children)
        uids = data.delete(:uids)
        tags = data.delete(:tags)
        super data:, key: do |tag|
          block.call(tag) if block_given?
          children&.each do |child|
            t = Teneo::FormatLibrary::Tag.from_hash(data: child, key: key, &block)
            tag.add_child_tag t
          end
          case uids
          when String
            uids&.split(/[\s,]+/)&.each do |uid|
              format = Teneo::FormatLibrary::Format.find(uid: uid.strip)
              raise "Format '#{uid}' not found" unless format

              tag.add_format format
            end
          when Array
            uids&.each do |uid|
              format = Teneo::FormatLibrary::Format.find(uid: uid.strip)
              raise "Format '#{uid}' not found" unless format

              tag.add_format format
            end
          end
          case tags
          when String
            tags&.split(/[\s,]+/)&.each do |t|
              child = Teneo::FormatLibrary::Tag.find(tag: t.strip)
              raise "Tag '#{t}' not found" unless child

              tag.add_child_tag child
            end
          when Array
            tags&.each do |t|
              child = Teneo::FormatLibrary::Tag.find(tag: t.strip)
              raise "Tag '#{t}' not found" unless child

              tag.add_child_tag child
            end
          end
        end
      end

      class DeepHash < Hash
        # Recursively searches for a key in the hash and its nested hash
        # values.
        #
        # @param key [Object] the key to search for
        # @return [Object] the value associated with the key, or +nil+ if the
        #   key is not found.
        def deep_find(key)
          return self[key] if key?(key)

          r = nil
          values.find { |x| r = x.deep_find(key) }
          r
        end

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
