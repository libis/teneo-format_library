# frozen_string_literal: true

namespace :teneo do
  namespace :format_library do
    desc 'Connect to the database '
    task :connect do
      puts 'Connecting to database ...'
      Teneo::FormatLibrary::Database.connect

      puts '>> Connected to database! <<'
    end
  end
end
