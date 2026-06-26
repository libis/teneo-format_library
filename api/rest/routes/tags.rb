# frozen_string_literal: true

require_relative '../base_app'
require 'yaml'

require_relative '../serializers/tag_serializer'
require_relative '../serializers/format_serializer'
require_relative '../lib/api_helpers'

module Routes
  class Tags < BaseApp
    route do |r|
      r.is do
        r.get do
          page, per_page = ApiHelpers.parse_pagination_params(r.params)

          dataset = Teneo::FormatLibrary::Tag.order(:tag)

          dataset = dataset.where(namespace: r.params['namespace']) if r.params['namespace']

          dataset = dataset.where(profile: r.params['profile']) if r.params['profile']

          result = ApiHelpers.paginate_dataset(dataset, page, per_page)
          result[:items] = Serializers::TagSerializer.collection(result[:items])
          result
        end
        r.post do
          data = r.params
          # Create tag explicitly to avoid writing generated columns
          tag = Teneo::FormatLibrary::Tag.new
          tag.tag = data['tag']
          tag.name = data['name'] if data['name']
          tag.profile = data['profile'] if data['profile']
          tag.properties = data['properties'] if data['properties']
          tag.info = data['info'] if data['info']
          tag.save

          # link formats/tags/children if provided
          Teneo::FormatLibrary::Tag.link_formats_to_tag(tag:, formats: data['formats']) if data['formats']
          Teneo::FormatLibrary::Tag.link_tags_to_tag(tag:, tags: data['tags']) if data['tags']
          Teneo::FormatLibrary::Tag.link_child_tags_to_tag(tag:, children: data['children'], key: nil) if data['children']

          Serializers::TagSerializer.call(tag)
        rescue StandardError => e
          r.halt(400, { error: e.message })
        end
      end

      r.on 'detail' do
        r.get do
          tag_id = r.params['tag']
          r.halt(400, { error: 'Query parameter "tag" is required' }) unless tag_id

          tag = Teneo::FormatLibrary::Tag[tag_id]
          r.halt(404, { error: "Tag '#{tag_id}' not found" }) unless tag

          include_formats = r.params['include_formats'] == 'true'
          include_ancestors = r.params['include_ancestors'] == 'true'
          include_descendants = r.params['include_descendants'] == 'true'

          Serializers::TagSerializer.call(tag,
                                          include_formats:,
                                          include_ancestors:,
                                          include_descendants:)
        end
        r.put do
          tag_id = r.params['tag']
          r.halt(400, { error: 'Query parameter "tag" is required' }) unless tag_id

          tag = Teneo::FormatLibrary::Tag[tag_id]
          r.halt(404, { error: "Tag '#{tag_id}' not found" }) unless tag

          begin
            data = r.params
            update_attrs = {}
            update_attrs[:name] = data['name'] if data.key?('name')
            update_attrs[:profile] = data['profile'] if data.key?('profile')
            update_attrs[:properties] = data['properties'] if data.key?('properties')
            update_attrs[:info] = data['info'] if data.key?('info')
            tag.update(update_attrs) unless update_attrs.empty?

            Teneo::FormatLibrary::Tag.link_formats_to_tag(tag:, formats: data['formats']) if data['formats']
            Teneo::FormatLibrary::Tag.link_tags_to_tag(tag:, tags: data['tags']) if data['tags']
            Teneo::FormatLibrary::Tag.link_child_tags_to_tag(tag:, children: data['children'], key: nil) if data['children']

            Serializers::TagSerializer.call(tag)
          rescue StandardError => e
            r.halt(400, { error: e.message })
          end
        end

        r.delete do
          tag_id = r.params['tag']
          r.halt(400, { error: 'Query parameter "tag" is required' }) unless tag_id

          tag = Teneo::FormatLibrary::Tag[tag_id]
          r.halt(404, { error: "Tag '#{tag_id}' not found" }) unless tag

          tag.delete
          { deleted: tag_id }
        end
      end

      r.on 'tree' do
        r.get do
          tag_id = r.params['tag']
          r.halt(400, { error: 'Query parameter "tag" is required' }) unless tag_id

          tag = Teneo::FormatLibrary::Tag[tag_id]
          r.halt(404, { error: "Tag '#{tag_id}' not found" }) unless tag

          include_formats = r.params['include_formats'] == 'true'

          Serializers::TagSerializer.tree_structure(tag, include_formats:)
        end
      end

      r.on 'formats' do
        r.get do
          tag_id = r.params['tag']
          r.halt(400, { error: 'Query parameter "tag" is required' }) unless tag_id

          tag = Teneo::FormatLibrary::Tag[tag_id]
          r.halt(404, { error: "Tag '#{tag_id}' not found" }) unless tag

          page, per_page = ApiHelpers.parse_pagination_params(r.params)
          dataset = tag.all_formats_ds.order(:uid)
          result = ApiHelpers.paginate_dataset(dataset, page, per_page)
          result[:items] = Serializers::FormatSerializer.collection(result[:items])
          result
        end
      end

      r.on 'upload' do
        r.post do
          items = parse_upload_items(r)
          created = items.map { |data| Teneo::FormatLibrary::Tag.from_hash_(data: data) }
          { count: created.count, items: Serializers::TagSerializer.collection(created) }
        rescue StandardError => e
          r.halt(400, { error: e.message })
        end
      end
    end

    private

    def parse_upload_items(req)
      file_param = req.params['file'] || req.params[:file]
      filename = nil
      content = nil

      if file_param
        filename = file_param[:filename] || file_param['filename']
        tempfile = file_param[:tempfile] || file_param['tempfile']
        content = tempfile&.read
      end

      content = req.body.read if content.nil? || content.empty?
      req.halt(400, { error: 'Request body or uploaded file is required' }) if content.nil? || content.strip.empty?

      upload_format = (req.params['format'] || req.params[:format]).to_s.downcase
      upload_format = File.extname(filename.to_s).delete('.').downcase if upload_format.empty? && filename
      upload_format = 'json' if upload_format.empty? && req.env['CONTENT_TYPE'].to_s.include?('json')
      upload_format = 'yaml' if upload_format.empty?

      parsed = case upload_format
               when 'json'
                 JSON.parse(content)
               when 'yaml', 'yml'
                 YAML.safe_load(content, permitted_classes: [Date, Time], aliases: true)
               else
                 req.halt(400, { error: 'Unsupported upload format. Use yaml, yml, or json.' })
               end

      items = [parsed].flatten.compact
      req.halt(400, { error: 'No records found in uploaded payload' }) if items.empty?

      items
    rescue JSON::ParserError, Psych::SyntaxError => e
      req.halt(400, { error: e.message })
    end
  end
end
