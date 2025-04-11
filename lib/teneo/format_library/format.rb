# frozen_string_literal: true

require_relative 'base'

require 'date'
require 'nokogiri'
require 'naturally'
require 'open-uri'
require 'zip'

module Teneo
  module FormatLibrary
    class Format < Teneo::FormatLibrary::Base
      many_to_many :tags, class: Teneo::FormatLibrary::Tag, join_table: :tagged_formats, left_key: :format, right_key: :tag

      # Returns a Hash with all tags associated with this format, directly or indirectly.
      #
      # @return [Hash<String, Teneo::FormatLibrary::Tag>] all tags associated with this format
      def all_tags_hash
        collected = {}
        tags.each do |tag|
          collected.merge!(tag.ancestors_hash)
        end
        collected
      end

      # Returns a dataset of all tags associated with this format, directly or indirectly.
      #
      # @return [Sequel::Dataset] a dataset of Tags
      def all_tags_ds
        # Tag.where(tag: all_tags.map(&:tag))
        db[:format_tags]
          .with_recursive(
            :format_tags,
            db[:tags].join(:tagged_formats, tag: :tag)
              .where(Sequel[:tagged_formats][:format] => uid)
              .select(Sequel.lit('tags.*')),
            db[:tags].join(:tagged_tags, parent: :tag)
              .join(:format_tags, tag: :tag)
              .select_all(:tags),
            cycle: { columns: :tag, cycle_value: true, noncycle_value: false }
          )
      end

      # Downloads the latest DROID signature file from the National Archives
      # site and inserts all file formats in the database.
      def self.load_pronom_signatures
        pronom_links = get_links(url: 'https://www.nationalarchives.gov.uk/aboutapps/pronom/droid-signature-files.htm',
                                 regex: %r{^https://cdn.nationalarchives.gov.uk/documents/DROID_SignatureFile_V\d*.xml})

        link = Naturally.sort(pronom_links).last
        parser = Nokogiri::XML::SAX::Parser.new(::Teneo::FormatLibrary::Format::DroidSignatureFilter.new)
        OpenURI.open_uri(link) do |data|
          parser.parse(data)
        end
      end

      def self.load_loc_signatures
        OpenURI.open_uri('https://www.loc.gov/preservation/digital/formats/fddXML.zip') do |url|
          Zip::File.open_buffer(url) do |zf|
            zf.each do |f|
              next unless f.ftype == :file && f.name =~ %r{^fddXML/fdd\d+\.xml$}

              fdd_parse(f.get_input_stream)
            end
          end
        end
      end

      # Parses the FDD XML file and creates or updates format entries in the database.
      # @param data [String] the XML data to parse
      def self.fdd_parse(data)
        doc = Nokogiri::XML::Document.parse(data)
        root = doc.root
        date = root.xpath('/fdd:FDD/fdd:properties/fdd:updates/fdd:date').first.inner_text
        format = {
          source: 'LOC',
          source_version: date,
          created_at: Date.parse(date),
          uid: root['id'],
          name: root['titleName'],
          url: "https://www.loc.gov/preservation/digital/formats/fdd/#{root['id']}.shtml"
        }
        sigs = root.xpath('/fdd:FDD/fdd:fileTypeSignifiers/fdd:signifiersGroup')
        format[:mimetypes] = xpath_to_array(element: sigs, xpath: 'fdd:internetMediaType/fdd:sigValues/fdd:sigValue')
        format[:extensions] = xpath_to_array(element: sigs, xpath: 'fdd:fileExtension/fdd:sigValues/fdd:sigValue')
        format[:related_formats] = xpath_to_array(
          element: sigs, xpath: "fdd:other/fdd:tag[. = 'Pronom PUID']/../fdd:values/fdd:sigValues/fdd:sigValue",
          filter: proc { |fmt| fmt =~ %r{fmt/} }
        )
        from_hash(data: format)
      end

      # Downloads the HTML from the provided URL, extracts all links, and filters the results
      # based on the provided regular expression. The method returns an array of strings,
      # each representing a link that matches the regular expression.
      def self.get_links(url:, regex:)
        Nokogiri::HTML(OpenURI.open_uri(url).read).css('a').map do |link|
          if (href = link.attr('href')) && href.match(regex)
            href
          end
        end.compact
      end

      # Converts an XML element to an array of strings based on the provided XPath.
      # @param element [Nokogiri::XML::Element] the XML element to convert
      # @param xpath [String] the XPath expression to use for the conversion
      # @return [Array<String>] an array of strings extracted from the XML element
      # @yield [String] a block to filter the resulting array of strings
      def self.xpath_to_array(element:, xpath:, filter: nil)
        filter ||= proc { true }
        element.xpath(xpath).map(&:inner_text).map(&:strip).select(&filter)
      end

      # SAX parser for the DROID signature file. It will create a format object for each file format found in the file.
      class DroidSignatureFilter < Nokogiri::XML::SAX::Document
        # Handles the start of an XML element.
        #
        # @param name [String] the name of the XML element
        # @param attrs [Array] an array of attribute-value pairs for the element
        #
        # Converts the attributes array to a hash for easier access. Sets the
        # @last_tag instance variable to the name of the element. If the element
        # is 'FFSignatureFile', it extracts the 'DateCreated' and 'Version' attributes.
        # If the element is 'FileFormat', it initializes a new format hash with
        # relevant attributes like name, uid, url, mimetypes, and version.

        def start_element(name, attrs = [])
          attrs = attrs.to_h
          @last_tag = name
          case name
          when 'FFSignatureFile'
            @date_created = attrs['DateCreated']
            @version = attrs['Version']
          when 'FileFormat'
            @format = { source: 'PRONOM', source_version: @version, created_at: Date.parse(@date_created) }
            @format[:name] = attrs['Name']
            @format[:uid] = attrs['PUID']
            @format[:url] = "https://www.nationalarchives.gov.uk/PRONOM/#{attrs['PUID']}"
            @format[:mimetypes] = attrs['MIMEType']&.split(',')&.map(&:strip) || []
            @format[:version] = attrs['Version']
            @format[:extensions] = []
          end
        end

        # Handles character data within an XML element.
        #
        # @param string [String] the character data within the XML element
        #
        # Appends the stripped character data to the @format[:extensions] array if
        # the current XML tag is 'Extension' and the stripped value is not empty.

        def characters(string)
          return unless @last_tag == 'Extension'

          value = string.strip
          @format[:extensions] << value unless value.empty?
        end

        # Handles the end of an XML element.
        #
        # @param name [String] the name of the XML element
        #
        # If the element is 'FileFormat', it calls {Teneo::FormatLibrary::Format.from_hash} with the current format hash as argument.

        def end_element(name)
          return unless name == 'FileFormat'

          Teneo::FormatLibrary::Format.from_hash(data: @format)
        end
      end
    end
  end
end
