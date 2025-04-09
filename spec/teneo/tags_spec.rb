# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Format Library' do
  it 'multiple formats can be tagged by the same tag' do
    tag = Teneo::FormatLibrary::Tag['BMP']
    expect(tag.formats.size).to be >= 7
    expect(tag.formats.map(&:uid)).to include('fmt/114')
  end

  it 'tags can be tagged by other tags' do
    tag = Teneo::FormatLibrary::Tag['BMP']
    expect(tag.ancestors_hash.size).to be >= 1
    expect(tag.ancestors_hash.size).to eq(tag.ancestors_ds.count)
    expect(tag.ancestors_hash.keys).to include('IMAGE')
    expect(tag.ancestors_ds.map { |t| t[:tag] }).to include('IMAGE')
  end

  it 'tagged tags can be found' do
    tag = Teneo::FormatLibrary::Tag['IMAGE']
    expect(tag.descendants_hash.size).to be >= 1
    expect(tag.descendants_hash.size).to eq(tag.descendants_ds.count)
    expect(tag.descendants_hash.keys).to include('BMP')
    expect(tag.descendants_ds.map { |t| t[:tag] }).to include('BMP')
  end

  it 'formats can be resolved recursively' do
    tag = Teneo::FormatLibrary::Tag['IMAGE']
    expect(tag.all_formats_ds.map { |fmt| fmt[:uid] }).to include('fmt/114')
  end
end
