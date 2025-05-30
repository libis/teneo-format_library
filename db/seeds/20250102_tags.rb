# frozen_string_literal: true

Sequel.seed(:production, :development, :test) do
  # Load all YAML files in the seeds directory and create or update the tags in
  # the database. The seeds directory is determined by the
  # `FORMAT_LIBRARY_SEEDS_TAG_DIR` environment variable. If this variable is not
  # set, the default directory is `db/seeds/data/tags`.
  def run
    puts 'Loading Format tags ...'
    seeds_data_dir = ENV.fetch('FORMAT_LIBRARY_SEEDS_TAG_DIR', File.join(File.dirname(__FILE__), 'data', 'tags'))
    Dir.glob(File.join(seeds_data_dir, '*.yml')).each do |file|
      puts "... from #{File.basename(file)} ..."
      # Load the YAML file and create or update the tag in the database
      Teneo::FormatLibrary::Tag.from_yaml_file(file:, key: :tag)
    end
  end
end
