# frozen_string_literal: true

Sequel.migration do
  change do
    puts "Creating table 'formats'..."
    create_table :formats do
      String :uid, null: false, primary_key: true

      String :name, null: false
      String :version

      String :source, null: false
      String :source_version

      String :url

      column :mimetypes, 'text[]', null: false, default: [], index: { type: :gin }
      column :extensions, 'text[]', null: false, default: [], index: { type: :gin }

      foreign_key :parent_format, :formats, type: String, null: true, on_delete: :cascade, on_update: :cascade
      column :related_formats, 'text[]', null: false, default: [], index: { type: :gin }

      column :properties, 'jsonb', null: false, default: '{}', index: { type: :gin }

      Date :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
