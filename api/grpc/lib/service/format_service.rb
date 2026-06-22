# frozen_string_literal: true

require_relative 'format_library_services_pb'
require 'teneo/format_library'
require 'json'
require 'grpc'

module Teneo
  module FormatLibrary
    module V1
      class FormatService < Teneo::FormatLibrary::V1::FormatService::Service
        def list_formats(request, _call)
          page = request.pagination&.page || 1
          per_page = request.pagination&.per_page || 50
          per_page = 100 if per_page > 100
          per_page = 1 if per_page < 1

          dataset = Teneo::FormatLibrary::Format.order(:uid)

          dataset = dataset.where(source: request.source) if request.source && !request.source.empty?
          if request.mimetype && !request.mimetype.empty?
            dataset = dataset.where(uid: Teneo::FormatLibrary::Format.db[:mimetypes].where(mimetype: request.mimetype).select(:format))
          end
          if request.extension && !request.extension.empty?
            dataset = dataset.where(uid: Teneo::FormatLibrary::Format.db[:extensions].where(extension: request.extension).select(:format))
          end

          if request.query && !request.query.empty?
            query = "%#{request.query}%"
            dataset = dataset.where(Sequel.ilike(:name, query) | Sequel.ilike(:uid, query))
          end

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

        def search_formats(request, _call)
          formats = Teneo::FormatLibrary::Format.where(Sequel.ilike(:name, "%#{request.query}%") | Sequel.ilike(:uid, "%#{request.query}%")).all
          Teneo::FormatLibrary::V1::SearchFormatsResponse.new(
            items: formats.map { |f| format_to_proto(f) }
          )
        end

        def get_format(request, _call)
          format = Teneo::FormatLibrary::Format[request.uid]
          raise GRPC::NotFound.new("Format '#{request.uid}' not found") unless format

          format_to_proto(format)
        end

        def get_format_relations(request, _call)
          format = Teneo::FormatLibrary::Format[request.uid]
          raise GRPC::NotFound.new("Format '#{request.uid}' not found") unless format

          relation_types = request.relation_types
          sources = request.sources
          formats = request.formats

          relations = format.relations(relation_types:, sources:, formats:)

          relations_proto = {}
          relations.each do |rel_type, rel_source|
            source_map = {}
            rel_source.each do |source, ids|
              source_map[source] = Teneo::FormatLibrary::V1::StringList.new(values: ids)
            end
            relations_proto[rel_type] = Teneo::FormatLibrary::V1::RelationSources.new(sources: source_map)
          end

          Teneo::FormatLibrary::V1::FormatRelationsResponse.new(relations: relations_proto)
        end

        def get_related_formats(request, _call)
          format = Teneo::FormatLibrary::Format[request.uid]
          raise GRPC::NotFound.new("Format '#{request.uid}' not found") unless format

          relation_types = request.relation_types
          sources = request.sources
          formats = request.formats

          related = format.related_formats(relation_types:, sources:, formats:)

          related_proto = {}
          related.each do |format_id, rel_data|
            source_map = {}
            rel_data.each do |rel_type, sources_list|
              source_map[rel_type] = Teneo::FormatLibrary::V1::StringList.new(values: sources_list)
            end
            related_proto[format_id] = Teneo::FormatLibrary::V1::RelatedSources.new(sources: source_map)
          end

          Teneo::FormatLibrary::V1::RelatedFormatsResponse.new(related: related_proto)
        end

        def get_format_tags(request, _call)
          format = Teneo::FormatLibrary::Format[request.uid]
          raise GRPC::NotFound.new("Format '#{request.uid}' not found") unless format

          tags = format.all_tags_hash(namespace: request.namespace.empty? ? nil : request.namespace,
                                      profile: request.profile.empty? ? nil : request.profile)
                       .values.map { |t| tag_to_proto(t, include_formats: false) }

          Teneo::FormatLibrary::V1::FormatTagsResponse.new(tags: tags)
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
