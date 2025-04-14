# frozen_string_literal: true

require 'bundler/setup'
require 'bundler/gem_tasks'

rakefile = './lib/teneo/format_library/Rakefile'
load rakefile

require 'github_changelog_generator/task'
GitHubChangelogGenerator::RakeTask.new :changelog do |config|
  config.user = 'libis'
  config.project = 'teneo-format_library'
  config.token = ENV['CHANGELOG_GITHUB_TOKEN']
  config.date_format = '%d/%m/%Y'
  config.unreleased = true
  config.verbose = false
end
