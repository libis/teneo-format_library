# frozen_string_literal: true

Sequel.migration do
  change do
    puts "Creating table 'extensions'..."
    create_table :extensions do
      String :extension
      foreign_key :format, :formats, type: String, key: :uid, null: false, on_delete: :cascade, on_update: :cascade
      primary_key %i[extension format]
    end
  end
end
