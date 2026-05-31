# frozen_string_literal: true

require 'roda'

class App < Roda
  route do |r|
    r.root do
      'Teneo Format Library'
    end
  end
end
