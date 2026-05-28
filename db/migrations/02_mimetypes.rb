# frozen_string_literal: true

Sequel.migration do
  change do
    puts "Creating table 'mimetypes'..."
    create_table :mimetypes do
      String :mimetype
      foreign_key :format, :formats, type: String, key: :uid, null: false, on_delete: :cascade, on_update: :cascade
      primary_key %i[mimetype format]
    end
  end
end
