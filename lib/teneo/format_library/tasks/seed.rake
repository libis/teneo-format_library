# frozen_string_literal: true

namespace :teneo do
  namespace :format_library do
    desc 'Run seeds'
    task seed: :connect do
      puts 'Run seeds'
      puts '========='
      require 'sequel/extensions/seed'
      Sequel.extension :seed
      $LOAD_PATH.unshift File.expand_path('lib', __dir__)
      Sequel::Seed.setup ENV.fetch('RUBY_ENV', 'development').to_sym
      seeds_dir = ENV.fetch('FORMAT_LIBRARY_SEEDS_DIR', File.join(__dir__, '..', '..', '..', '..', 'db', 'seeds'))
      Sequel::Seeder.apply(::Teneo::FormatLibrary.db, seeds_dir)
    end
  end
end
