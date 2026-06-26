# frozen_string_literal: true

module Serializers
  module TagSerializer
    def self.call(tag, include_formats: false, include_ancestors: false, include_descendants: false)
      result = {
        tag: tag.tag,
        name: tag.name,
        profile: tag.profile,
        properties: tag.properties || {},
        info: tag.info || {}
      }

      if include_formats
        formats = tag.all_formats_hash
        formats = formats.values if formats.respond_to?(:values)
        result[:formats] = formats.map do |format|
          format = format.last if format.is_a?(Array)
          { uid: format.uid, name: format.name, version: format.version }.compact
        end
      end

      result[:ancestors] = tag.ancestors_ds.all.map { |t| t.slice(:tag, :path, :name, :profile) } if include_ancestors

      result[:descendants] = tag.descendants_ds.all if include_descendants

      result
    end

    def self.collection(tags)
      tags.map { |t| call(t) }
    end

    def self.tree_structure(tag, include_formats: false)
      return tree_formats(tag) if include_formats

      tag.tree_structure
    end

    def self.tree_formats(tag)
      tag.tree_formats
    end
  end
end
