# frozen_string_literal: true

require_relative '../base_app'
require_relative '../serializers/format_serializer'
require_relative '../lib/api_helpers'
require 'yaml'

module Routes
  class Formats < BaseApp
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
          result
        end
        r.post do
          data = r.params
          required = %w[uid name source]
          missing = required.reject { |key| data[key] }
          r.halt(400, { error: "Missing required fields: #{missing.join(', ')}" }) unless missing.empty?

          format = Teneo::FormatLibrary::Format.from_hash_(data: data)
          Serializers::FormatSerializer.call(format)
        rescue StandardError => e
          r.halt(400, { error: e.message })
        end
      end

      r.on 'search' do
        r.get do
          query = r.params['q']
          r.halt(400, { error: 'Query parameter "q" is required' }) unless query

          formats = Teneo::FormatLibrary::Format.where(Sequel.ilike(:name, "%#{query}%") | Sequel.ilike(:uid, "%#{query}%")).all
          { items: Serializers::FormatSerializer.collection(formats) }
        end
      end

      r.on 'upload' do
        r.post do
          items = parse_upload_items(r)
          created = items.map { |data| Teneo::FormatLibrary::Format.from_hash_(data: data) }
          { count: created.count, items: Serializers::FormatSerializer.collection(created) }
        rescue StandardError => e
          r.halt(400, { error: e.message })
        end
      end

      r.on 'detail' do
        r.get do
          uid = r.params['uid']
          r.halt(400, { error: 'Query parameter "uid" is required' }) unless uid

          format = Teneo::FormatLibrary::Format[uid]
          r.halt(404, { error: "Format '#{uid}' not found" }) unless format

          Serializers::FormatSerializer.call(format)
        end
        r.put do
          uid = r.params['uid']
          r.halt(400, { error: 'Query parameter "uid" is required' }) unless uid

          format = Teneo::FormatLibrary::Format[uid]
          r.halt(404, { error: "Format '#{uid}' not found" }) unless format

          begin
            data = r.params
            update_attrs = {}
            update_attrs[:name] = data['name'] if data.key?('name')
            update_attrs[:version] = data['version'] if data.key?('version')
            update_attrs[:source] = data['source'] if data.key?('source')
            update_attrs[:source_version] = data['source_version'] if data.key?('source_version')
            update_attrs[:url] = data['url'] if data.key?('url')
            update_attrs[:properties] = data['properties'] if data.key?('properties')
            update_attrs[:created_at] = data['created_at'] if data.key?('created_at')
            format.update(update_attrs) unless update_attrs.empty?

            format.mimetypes = data['mimetypes'] if data.key?('mimetypes')
            format.extensions = data['extensions'] if data.key?('extensions')
            [data['relations']].flatten.compact.each do |relation|
              format.add_relation(
                related_format: relation['related_format'] || relation[:related_format],
                relation_type: relation['relation_type'] || relation[:relation_type],
                inverse_relation_type: relation['inverse_relation_type'] || relation[:inverse_relation_type]
              )
            end

            Serializers::FormatSerializer.call(format)
          rescue StandardError => e
            r.halt(400, { error: e.message })
          end
        end

        r.delete do
          uid = r.params['uid']
          r.halt(400, { error: 'Query parameter "uid" is required' }) unless uid

          format = Teneo::FormatLibrary::Format[uid]
          r.halt(404, { error: "Format '#{uid}' not found" }) unless format

          format.delete
          { deleted: uid }
        end
      end

      r.on 'relations' do
        r.get do
          uid = r.params['uid']
          r.halt(400, { error: 'Query parameter "uid" is required' }) unless uid

          format = Teneo::FormatLibrary::Format[uid]
          r.halt(404, { error: "Format '#{uid}' not found" }) unless format

          relation_types = r.params['relation_types']&.split(',')
          sources = r.params['sources']&.split(',')
          formats = r.params['formats']&.split(',')

          format.relations(relation_types:, sources:, formats:)
        end
      end

      r.on 'related' do
        r.get do
          uid = r.params['uid']
          r.halt(400, { error: 'Query parameter "uid" is required' }) unless uid

          format = Teneo::FormatLibrary::Format[uid]
          r.halt(404, { error: "Format '#{uid}' not found" }) unless format

          relation_types = r.params['relation_types']&.split(',')
          sources = r.params['sources']&.split(',')
          formats = r.params['formats']&.split(',')

          format.related_formats(relation_types:, sources:, formats:)
        end
      end

      r.on 'tags' do
        r.get do
          uid = r.params['uid']
          r.halt(400, { error: 'Query parameter "uid" is required' }) unless uid

          format = Teneo::FormatLibrary::Format[uid]
          r.halt(404, { error: "Format '#{uid}' not found" }) unless format

          namespace = r.params['namespace']
          profile = r.params['profile']

          format.all_tags_hash(namespace:, profile:).values.map do |tag|
            { tag: tag.tag, name: tag.name, profile: tag.profile, namespace: tag.namespace }
          end
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
