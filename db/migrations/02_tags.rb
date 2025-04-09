# frozen_string_literal: true

Sequel.migration do
  change do
    puts "Creating table 'tags'..."
    create_table :tags do
      String :tag, null: false, primary_key: true
      String :name, null: false

      String :profile, null: false, index: true
      column :properties, 'jsonb', index: { type: :gin }
      column :info, 'jsonb'
    end
  end
end
