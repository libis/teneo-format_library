# frozen_string_literal: true

require 'teneo/format_library/format'

Sequel.seed(:production, :development, :test) do
  # Loads CSV files from the format library directory and updates or creates
  # format entries in the database.
  #
  # For each CSV file found, it extracts the library version from the filename,
  # reads the file, and processes each row. The row data is merged with the
  # library version and passed to update_or_create to update or create a format
  # entry in the Teneo::DataModel::Format model. The CSV header conversion is
  # done using the header_converter method.

  def run
    puts 'Loading PRONOM Signatures data ...'
    Teneo::FormatLibrary::Format.load_pronom_signatures

    puts 'Loading LOC Signatures data ...'
    Teneo::FormatLibrary::Format.load_loc_signatures

    puts 'Loading Teneo formats data ...'
    seeds_data_dir = ENV.fetch('SEEDS_DATA_DIR', File.join(File.dirname(__FILE__), 'data'))
    Teneo::FormatLibrary::Format.from_yaml_file(file: File.join(seeds_data_dir, 'teneo_formats.yml'))
  end
end
