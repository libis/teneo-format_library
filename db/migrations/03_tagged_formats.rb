# frozen_string_literal: true

Sequel.migration do
  change do
    puts "Creating table 'tagged_formats'..."
    create_table :tagged_formats do
      foreign_key :tag, :tags, type: String, key: :tag, null: false, on_delete: :cascade, on_update: :cascade
      foreign_key :format, :formats, type: String, key: :uid, null: false, on_delete: :cascade, on_update: :cascade

      primary_key %i[tag format]
    end
  end
end
