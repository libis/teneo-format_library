# frozen_string_literal: true

require_relative '../base_app'

module Routes
  class Doc < BaseApp
    DOC_ROOT = File.expand_path('../doc', __dir__)
    DOC_CONTENT_TYPES = {
      '.html' => 'text/html; charset=utf-8',
      '.css' => 'text/css; charset=utf-8',
      '.js' => 'application/javascript; charset=utf-8',
      '.json' => 'application/json; charset=utf-8',
      '.yaml' => 'application/yaml; charset=utf-8',
      '.yml' => 'application/yaml; charset=utf-8',
      '.png' => 'image/png'
    }.freeze

    route do |r|
      r.is do
        r.get do
          serve_doc_file('index.html')
        end
      end

      r.get String do |path|
        serve_doc_file(path)
      end
    end

    private

    def serve_doc_file(path)
      cleaned_path = path.to_s.strip
      return doc_not_found if cleaned_path.empty?

      full_path = File.expand_path(cleaned_path, DOC_ROOT)
      return doc_not_found unless full_path.start_with?("#{DOC_ROOT}/") && File.file?(full_path)

      response['Content-Type'] = DOC_CONTENT_TYPES.fetch(File.extname(full_path).downcase, 'application/octet-stream')
      File.binread(full_path)
    end

    def doc_not_found
      response.status = 404
      { error: 'Document not found' }
    end
  end
end
