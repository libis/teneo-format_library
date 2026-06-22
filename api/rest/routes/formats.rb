# frozen_string_literal: true

require_relative '../serializers/format_serializer'
require_relative '../lib/api_helpers'

module Routes
  class Formats < Roda
    plugin :halt

    route do |r|
      r.is do
        r.get do
          page, per_page = ApiHelpers.parse_pagination_params(r.params)

          dataset = Teneo::FormatLibrary::Format.order(:uid)

          dataset = dataset.where(source: r.params['source']) if r.params['source']

          dataset = dataset.where(uid: Teneo::FormatLibrary::Format.db[:mimetypes].where(mimetype: r.params['mimetype']).select(:format)) if r.params['mimetype']

          dataset = dataset.where(uid: Teneo::FormatLibrary::Format.db[:extensions].where(extension: r.params['extension']).select(:format)) if r.params['extension']

          if r.params['q']
            query = "%#{r.params['q']}%"
            dataset = dataset.where(Sequel.ilike(:name, query) | Sequel.ilike(:uid, query))
          end

          result = ApiHelpers.paginate_dataset(dataset, page, per_page)
          result[:items] = Serializers::FormatSerializer.collection(result[:items])
          response['Content-Type'] = 'application/json'
          result.to_json
        end
      end

      r.on 'search' do
        r.get do
          query = r.params['q']
          r.halt(400, { error: 'Query parameter "q" is required' }.to_json) unless query

          formats = Teneo::FormatLibrary::Format.where(Sequel.ilike(:name, "%#{query}%") | Sequel.ilike(:uid, "%#{query}%")).all
          response['Content-Type'] = 'application/json'
          { items: Serializers::FormatSerializer.collection(formats) }.to_json
        end
      end

      r.on 'detail' do
        r.get do
          uid = r.params['uid']
          r.halt(400, { error: 'Query parameter "uid" is required' }.to_json) unless uid

          format = Teneo::FormatLibrary::Format[uid]
          r.halt(404, { error: "Format '#{uid}' not found" }.to_json) unless format

          response['Content-Type'] = 'application/json'
          Serializers::FormatSerializer.call(format).to_json
        end
      end

      r.on 'relations' do
        r.get do
          uid = r.params['uid']
          r.halt(400, { error: 'Query parameter "uid" is required' }.to_json) unless uid

          format = Teneo::FormatLibrary::Format[uid]
          r.halt(404, { error: "Format '#{uid}' not found" }.to_json) unless format

          relation_types = r.params['relation_types']&.split(',')
          sources = r.params['sources']&.split(',')
          formats = r.params['formats']&.split(',')

          response['Content-Type'] = 'application/json'
          format.relations(relation_types:, sources:, formats:).to_json
        end
      end

      r.on 'related' do
        r.get do
          uid = r.params['uid']
          r.halt(400, { error: 'Query parameter "uid" is required' }.to_json) unless uid

          format = Teneo::FormatLibrary::Format[uid]
          r.halt(404, { error: "Format '#{uid}' not found" }.to_json) unless format

          relation_types = r.params['relation_types']&.split(',')
          sources = r.params['sources']&.split(',')
          formats = r.params['formats']&.split(',')

          response['Content-Type'] = 'application/json'
          format.related_formats(relation_types:, sources:, formats:).to_json
        end
      end

      r.on 'tags' do
        r.get do
          uid = r.params['uid']
          r.halt(400, { error: 'Query parameter "uid" is required' }.to_json) unless uid

          format = Teneo::FormatLibrary::Format[uid]
          r.halt(404, { error: "Format '#{uid}' not found" }.to_json) unless format

          namespace = r.params['namespace']
          profile = r.params['profile']

          response['Content-Type'] = 'application/json'
          format.all_tags_hash(namespace:, profile:).values.map do |tag|
            { tag: tag.tag, name: tag.name, profile: tag.profile, namespace: tag.namespace }
          end.to_json
        end
      end
    end
  end
end
