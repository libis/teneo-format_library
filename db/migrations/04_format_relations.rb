# frozen_string_literal: true

Sequel.migration do
  change do
    puts "Creating table 'format_relations'..."
    create_table :format_relations do
      String :uid, null: false
      String :related_format, null: false
      String :relation_type, null: false
      String :source, null: false
      String :source_version
      primary_key %i[uid related_format relation_type source]
    end
  end
end
