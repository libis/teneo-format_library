# frozen_string_literal: true

Sequel.seed(:production, :development, :test) do
  def run
    puts 'Loading Format tags ...'
    seeds_data_dir = ENV.fetch('SEEDS_DATA_DIR', File.join(File.dirname(__FILE__), 'data'))
    Teneo::FormatLibrary::Tag.from_yaml_file(file: File.join(seeds_data_dir, 'teneo_tags.yml'),
                                             key: :tag) do |tag|
      tag.profile = 'teneo'
    end

    puts 'Loading Web tags ...'
    seeds_data_dir = ENV.fetch('SEEDS_DATA_DIR', File.join(File.dirname(__FILE__), 'data'))
    Teneo::FormatLibrary::Tag.from_yaml_file(file: File.join(seeds_data_dir, 'web_tags.yml'),
                                             key: :tag) do |tag|
    end
  end
end
