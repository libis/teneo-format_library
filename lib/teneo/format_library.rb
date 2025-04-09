# frozen_string_literal: true

require 'sequel'

Sequel.extension :core_refinements

module Teneo
  module FormatLibrary
    autoload :Database, 'teneo/format_library/database'
    autoload :Format, 'teneo/format_library/format'
    autoload :Tag, 'teneo/format_library/tag'

    def self.db
      Database.connect
    end
  end
end
