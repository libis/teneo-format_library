# frozen_string_literal: true

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError # rubocop:disable Lint/SuppressedException
end

$LOAD_PATH.unshift 'lib'

import './lib/teneo/format_library/Rakefile'
