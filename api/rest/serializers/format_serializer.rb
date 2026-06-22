# frozen_string_literal: true

module Serializers
  module FormatSerializer
    def self.call(format)
      if format.is_a?(Hash)
        uid = format[:uid] || format['uid']
        return nil unless uid

        fmt = Teneo::FormatLibrary::Format[uid]
        return nil unless fmt

        return call(fmt)
      end

      {
        uid: format.uid,
        name: format.name,
        version: format.version,
        source: format.source,
        source_version: format.source_version,
        url: format.url,
        properties: format.properties || {},
        mimetypes: format.mimetypes,
        extensions: format.extensions,
        created_at: format.created_at&.iso8601
      }
    end

    def self.collection(formats)
      formats.map { |f| call(f) }.compact
    end
  end
end
