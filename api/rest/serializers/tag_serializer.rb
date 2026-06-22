# frozen_string_literal: true

module Serializers
  module TagSerializer
    def self.call(tag, include_formats: false, include_ancestors: false, include_descendants: false)
      result = {
        tag: tag.tag,
        name: tag.name,
        profile: tag.profile,
        namespace: tag.namespace
      }

      result[:formats] = tag.formats.map { |f| { uid: f.uid, name: f.name, version: f.version }.compact } if include_formats

      result[:ancestors] = tag.ancestors_hash.map { |_, t| { tag: t.tag, name: t.name, profile: t.profile } } if include_ancestors

      result[:descendants] = tag.descendants_hash.map { |_, t| { tag: t.tag, name: t.name, profile: t.profile } } if include_descendants

      result
    end

    def self.collection(tags)
      tags.map { |t| call(t) }
    end

    def self.tree_structure(tag)
      tag.tree_structure
    end

    def self.tree_formats(tag)
      tag.tree_formats
    end
  end
end
