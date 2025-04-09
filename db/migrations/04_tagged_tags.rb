# frozen_string_literal: true

Sequel.migration do
  change do
    puts "Creating table 'tagged_tags'..."
    create_table :tagged_tags do
      foreign_key :tag, :tags, type: String, key: :tag, null: false, on_delete: :cascade, on_update: :cascade
      foreign_key :parent, :tags, type: String, key: :tag, null: false, on_delete: :cascade, on_update: :cascade

      primary_key %i[tag parent]
    end
  end
end
