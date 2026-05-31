# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Format Library' do
  it 'has list of formats' do
    fmt = Teneo::FormatLibrary::Format['fmt/1']
    expect(fmt).not_to be nil
    expect(fmt.name).to eq('Broadcast WAVE')
    expect(fmt.version).to eq('0 Generic')
    expect(fmt.source).to eq('PRONOM')
  end

  it 'has tags attached to formats' do
    fmt = Teneo::FormatLibrary::Format['fmt/114']
    expect(fmt.tags.size).to be >= 1
    expect(fmt.tags.map(&:tag)).to include('BMP')
    expect(fmt.tags.map(&:tag)).not_to include('IMAGE')
    expect(fmt.all_tags_hash.keys).to include('BMP')
    expect(fmt.all_tags_hash.keys).to include('IMAGE')
    expect(fmt.all_tags_ds.map { |t| t[:tag] }).to include('BMP')
    expect(fmt.all_tags_ds.map { |t| t[:tag] }).to include('IMAGE')
  end
end
