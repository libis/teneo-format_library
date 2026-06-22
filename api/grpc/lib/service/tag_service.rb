# frozen_string_literal: true

require_relative 'format_library_services_pb'
require 'teneo/format_library'

module Teneo
  module FormatLibrary
    module V1
      class TagService < Teneo::FormatLibrary::V1::TagService::Service
        def list_tags(request, _call)
          page = request.pagination&.page || 1
          per_page = request.pagination&.per_page || 50
          per_page = min(per_page, 100)
          per_page = max(per_page, 1)

          dataset = Teneo::FormatLibrary::Tag.order(:tag)

          dataset = dataset.where(namespace: request.namespace) unless request.namespace.blank?
          dataset = dataset.where(profile: request.profile) unless request.profile.blank?

          total = dataset.count
          offset = (page - 1) * per_page
          items = dataset.limit(per_page, offset).all.map { |t| tag_to_proto(t) }

          Teneo::FormatLibrary::V1::ListTagsResponse.new(
            items: items,
            pagination: Teneo::FormatLibrary::V1::PaginationResponse.new(
              page: page,
              per_page: per_page,
              total: total,
              total_pages: (total.to_f / per_page).ceil
            )
          )
        end

        def get_tag(request, _call)
          tag = Teneo::FormatLibrary::Tag[request.tag]
          raise GRPC::NotFound.new("Tag '#{request.tag}' not found") unless tag

          tag_to_proto(
            tag,
            include_formats: request.include_formats,
            include_ancestors: request.include_ancestors,
            include_descendants: request.include_descendants
          )
        end

        def get_tag_formats(request, _call)
          tag = Teneo::FormatLibrary::Tag[request.tag]
          raise GRPC::NotFound.new("Tag '#{request.tag}' not found") unless tag

          page = request.pagination&.page || 1
          per_page = request.pagination&.per_page || 50
          per_page = 100 if per_page > 100
          per_page = 1 if per_page < 1

          dataset = tag.all_formats_ds.order(:uid)
          total = dataset.count
          offset = (page - 1) * per_page
          items = dataset.limit(per_page, offset).all.map { |f| format_to_proto(f) }

          Teneo::FormatLibrary::V1::ListFormatsResponse.new(
            items: items,
            pagination: Teneo::FormatLibrary::V1::PaginationResponse.new(
              page: page,
              per_page: per_page,
              total: total,
              total_pages: (total.to_f / per_page).ceil
            )
          )
        end

        private

        def format_to_proto(format)
          Teneo::FormatLibrary::V1::Format.new(
            uid: format.uid,
            name: format.name,
            version: format.version || '',
            source: format.source,
            source_version: format.source_version || '',
            url: format.url || '',
            properties: format.properties || {},
            mimetypes: format.mimetypes,
            extensions: format.extensions,
            created_at: format.created_at&.iso8601 || ''
          )
        end

        def tag_to_proto(tag, include_formats: false, include_ancestors: false, include_descendants: false)
          result = Teneo::FormatLibrary::V1::Tag.new(
            tag: tag.tag,
            name: tag.name,
            profile: tag.profile,
            namespace: tag.namespace
          )

          result.formats = tag.formats.map { |f| format_to_proto(f) } if include_formats

          result.ancestors = tag.ancestors_hash.values.map { |t| tag_to_proto(t) } if include_ancestors

          result.descendants = tag.descendants_hash.values.map { |t| tag_to_proto(t) } if include_descendants

          result
        end
      end
    end
  end
end
