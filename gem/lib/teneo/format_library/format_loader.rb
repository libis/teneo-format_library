# frozen_string_literal: true

require_relative 'format'

require 'nokogiri'
require 'open-uri'
require 'zip'

module Teneo
  module FormatLibrary
    class FormatLoader
      # Downloads the latest DROID signature file from the National Archives site and updates the format library
      #
      # @param version [String, nil] an optional PRONOM signature file version number; default: latest version
      def self.load_pronom_signatures(version: nil)
        link = nil

        if version
          link = "https://cdn.nationalarchives.gov.uk/documents/DROID_SignatureFile_V#{version}.xml"
        else
          pronom_links = get_links(
            url: 'https://www.nationalarchives.gov.uk/aboutapps/pronom/droid-signature-files.htm',
            regex: %r{^https://cdn.nationalarchives.gov.uk/documents/DROID_SignatureFile_V\d*.xml}
          )
          link = Naturally.sort(pronom_links).last
        end

        pronom_parse(OpenURI.open_uri(link).read)

        # Delete older PRONOM formats; mimetypes and extensions will also be deleted
        version = link.match(/DROID_SignatureFile_V(\d+)\.xml/)[1]
        Teneo::FormatLibrary::Format.where(source: 'PRONOM').exclude(source_version: version).delete

        # No foreign key constraints on the format_relations table; delete any old relations
        Teneo::FormatLibrary::Database.connect[:format_relations].where(source: 'PRONOM').exclude(source_version: version).delete
      end

      # Parses the DROID signature XML file and creates or updates format entries in the database.
      #
      # @param data [String] the XML data to parse
      def self.pronom_parse(data)
        doc = Nokogiri::XML::Document.parse(data)
        doc.remove_namespaces!
        root = doc.root
        version = root['Version']
        date = root['DateCreated']
        root.xpath('/FFSignatureFile/FileFormatCollection/FileFormat').each do |file_format|
          data = {
            uid: file_format['PUID'],
            name: file_format['Name'],
            version: file_format['Version'],
            source: 'PRONOM',
            source_version: version,
            created_at: date,
            url: "https://www.nationalarchives.gov.uk/PRONOM/#{file_format['PUID']}",
            mimetypes: file_format['MIMEType']&.split(',')&.map(&:strip)&.compact&.uniq || [],
            extensions: xpath_to_array(element: file_format, xpath: 'Extension').compact.uniq
          }
          fmt = Teneo::FormatLibrary::Format.from_hash(data:)
          xpath_to_array(element: file_format, xpath: 'HasPriorityOverFileFormatID').each do |related_uid|
            related_format = doc.xpath("/FFSignatureFile/FileFormatCollection/FileFormat[@ID='#{related_uid}']").first
            fmt.add_relation(
              related_format: related_format['PUID'],
              relation_type: 'has_priority_over',
              inverse_relation_type: 'has_lower_priority_than'
            )
          end
        end
      end

      # Download the latest FDD XML file from the Library of Congress site
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
      #
      # @param data [String] the XML data to parse
      def self.fdd_parse(data)
        doc = Nokogiri::XML::Document.parse(data)
        root = doc.root
        date = xpath_to_array(element: root, xpath: '/fdd:FDD/fdd:properties/fdd:updates/fdd:date').last
        sigs = root.xpath('/fdd:FDD/fdd:fileTypeSignifiers/fdd:signifiersGroup')
        data = {
          source: 'LOC',
          source_version: date,
          created_at: date,
          uid: root['id'],
          name: root['titleName'],
          url: "https://www.loc.gov/preservation/digital/formats/fdd/#{root['id']}.shtml",
          mimetypes: xpath_to_array(element: sigs, xpath: 'fdd:internetMediaType/fdd:sigValues/fdd:sigValue').compact.uniq,
          extensions: xpath_to_array(element: sigs, xpath: 'fdd:filenameExtension/fdd:sigValues/fdd:sigValue').compact.uniq
        }
        fmt = Teneo::FormatLibrary::Format.from_hash(data:)
        xpath_to_array(
          element: sigs,
          xpath: 'fdd:other/fdd:tag/fdd:values/fdd:sigValues/fdd:sigValue'
        ).each do |related_uid|
          fmt.add_relation(
            related_format: related_uid,
            relation_type: 'related_format',
            inverse_relation_type: 'related_format'
          )
        end
        root.xpath('/fdd:FDD/fdd:identificationAndDescription/fdd:relationships/fdd:relationship').each do |relationship|
          relationship_type = xpath_to_array(element: relationship, xpath: 'fdd:typeOfRelationship').first
          xpath_to_array(element: relationship, xpath: 'fdd:relatedTo/fdd:id').each do |related_uid|
            fmt.add_relation(
              related_format: related_uid,
              relation_type: relationship_type.tr(' ', '_').downcase
            )
          end
        end
        fmt
      end

      # Downloads the HTML from the provided URL, extracts all links, and filters the results
      # based on the provided regular expression.
      def self.get_links(url:, regex:)
        Nokogiri::HTML(OpenURI.open_uri(url).read).css('a').map do |link|
          if (href = link.attr('href')) && href.match(regex)
            href
          end
        end.compact
      end

      # Retrieves the inner text of all matching nodes.
      #
      # @param element [Nokogiri::XML::Element] the XML element to convert
      # @param xpath [String] the XPath expression to use for the conversion
      # @param filter [Proc] a block to filter the resulting array of strings
      # @return [Array<String>] an array of strings extracted from the XML element
      def self.xpath_to_array(element:, xpath:, filter: nil)
        filter ||= proc { true }
        element.xpath(xpath).map(&:inner_text).map(&:strip).select(&filter)
      end
    end
  end
end
