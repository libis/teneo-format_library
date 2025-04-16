# frozen_string_literal: true

require 'teneo/format_library/format'

Sequel.seed(:production, :development, :test) do
  # Seeds the database with all formats from PRONOM and LOC signature files and
  # extra formats from the directory specified by the `FORMAT_LIBRARY_SEEDS_FORMAT_DIR`
  # environment variable (defaulting to `db/seeds/data/formats/`).
  def run
    puts 'Loading PRONOM Signatures data ...'
    Teneo::FormatLibrary::Format.load_pronom_signatures

    puts 'Loading LOC Signatures data ...'
    Teneo::FormatLibrary::Format.load_loc_signatures

    puts 'Loading extra formats data ...'
    seeds_data_dir = ENV.fetch('FORMAT_LIBRARY_SEEDS_FORMAT_DIR', File.join(File.dirname(__FILE__), 'data', 'formats'))
    Dir.glob(File.join(seeds_data_dir, '*.yml')).each do |file|
      puts "... from #{File.basename(file)} ..."
      Teneo::FormatLibrary::Format.from_yaml_file(file:)
    end
  end
end
