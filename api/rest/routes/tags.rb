# frozen_string_literal: true

require_relative '../serializers/tag_serializer'
require_relative '../serializers/format_serializer'
require_relative '../lib/api_helpers'

module Routes
  class Tags < Roda
    plugin :halt

    route do |r|
      r.is do
        r.get do
          page, per_page = ApiHelpers.parse_pagination_params(r.params)

          dataset = Teneo::FormatLibrary::Tag.order(:tag)

          dataset = dataset.where(namespace: r.params['namespace']) if r.params['namespace']

          dataset = dataset.where(profile: r.params['profile']) if r.params['profile']

          result = ApiHelpers.paginate_dataset(dataset, page, per_page)
          result[:items] = Serializers::TagSerializer.collection(result[:items])
          response['Content-Type'] = 'application/json'
          result.to_json
        end
      end

      r.on 'detail' do
        r.get do
          tag_id = r.params['tag']
          r.halt(400, { error: 'Query parameter "tag" is required' }.to_json) unless tag_id

          tag = Teneo::FormatLibrary::Tag[tag_id]
          r.halt(404, { error: "Tag '#{tag_id}' not found" }.to_json) unless tag

          include_formats = r.params['include_formats'] == 'true'
          include_ancestors = r.params['include_ancestors'] == 'true'
          include_descendants = r.params['include_descendants'] == 'true'

          response['Content-Type'] = 'application/json'
          Serializers::TagSerializer.call(tag,
                                          include_formats:,
                                          include_ancestors:,
                                          include_descendants:).to_json
        end
      end

      r.on 'formats' do
        r.get do
          tag_id = r.params['tag']
          r.halt(400, { error: 'Query parameter "tag" is required' }.to_json) unless tag_id

          tag = Teneo::FormatLibrary::Tag[tag_id]
          r.halt(404, { error: "Tag '#{tag_id}' not found" }.to_json) unless tag

          page, per_page = ApiHelpers.parse_pagination_params(r.params)
          dataset = tag.all_formats_ds.order(:uid)
          result = ApiHelpers.paginate_dataset(dataset, page, per_page)
          result[:items] = Serializers::FormatSerializer.collection(result[:items])
          response['Content-Type'] = 'application/json'
          result.to_json
        end
      end
    end
  end
end
