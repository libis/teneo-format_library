# frozen_string_literal: true

namespace :teneo do
  namespace :format_library do
    desc 'Run migrations'
    task :migrate, [:version] => :connect do |_t, args|
      puts 'Run migrations'
      puts '=============='
      require 'sequel/core'
      Sequel.extension :migration
      version = args[:version].to_i if args[:version]
      migrations_dir = ENV.fetch('FORMAT_LIBRARY_MIGRATIONS_DIR', File.join(__dir__, '..', '..', '..', '..', 'db', 'migrations'))
      Sequel::Migrator.run(::Teneo::FormatLibrary.db, migrations_dir, target: version)
    end
  end
end
