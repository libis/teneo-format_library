# frozen_string_literal: true

require_relative 'lib/teneo/format_library/version'

Gem::Specification.new do |spec|
  spec.name = 'teneo-format_library'
  spec.version = Teneo::FormatLibrary::VERSION
  spec.authors = ['Kris Dekeyser']
  spec.email = ['kris.dekeyser@kuleuven.be']

  spec.summary = 'Format Library classes for Teneo'
  spec.description = 'This gem provides the Format Library for Teneo'
  spec.homepage = 'https://github.com/LIBIS/teneo-format_library'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.4.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.pkg.github.com/libis'

  spec.metadata['source_code_uri'] = 'https://github.com/LIBIS/gem/teneo-format_library'
  spec.metadata['changelog_uri'] = 'https://github.com/LIBIS/teneo-format_library/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files =
    Dir.glob('lib/**/*') +
    Dir.glob('db/migrations/*') +
    Dir.glob('db/seeds/*') +
    [
      'teneo-format_library.gemspec',
      'Gemfile',
      'Gemfile.lock',
      'README.md',
      'LICENSE'
    ]
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activesupport', '~> 8.0', '>= 8.1.3'
  spec.add_runtime_dependency 'csv', '~> 3.0', '>= 3.3.5'
  spec.add_runtime_dependency 'naturally', '~> 2.0', '>= 2.3.0'
  spec.add_runtime_dependency 'nokogiri', '~> 1.0', '>= 1.19.3'
  spec.add_runtime_dependency 'rubyzip', '~> 3.3', '>= 3.3.0'

  spec.add_runtime_dependency 'faraday-retry', '~> 2.0', '>= 2.4.0'
  spec.add_runtime_dependency 'pg', '~> 1.0', '>= 1.6.3'
  spec.add_runtime_dependency 'sequel', '~> 5.0', '>= 5.104.0'
  spec.add_runtime_dependency 'sequel_pg', '~> 1.0', '>= 1.19.0'
  spec.add_runtime_dependency 'sequel-seed', '~> 1.0', '>= 1.1.2'

  spec.add_runtime_dependency 'dotenv', '~> 3.0', '>= 3.2.0'
end
