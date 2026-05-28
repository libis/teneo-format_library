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
      unrestrict_primary_key

      many_to_many :tags, class: Teneo::FormatLibrary::Tag, join_table: :tagged_formats, left_key: :format, right_key: :tag

      def mimetypes(value = nil)
        if value
          current_values = db[:mimetypes].where(format: uid).get(:mimetype) || []
          new_values = [value].flatten.uniq
          to_add = new_values - current_values
          to_remove = current_values - new_values
          to_add.each do |mt|
            db[:mimetypes].insert(mimetype: mt, format: uid)
          end
          to_remove.each do |mt|
            db[:mimetypes].where(mimetype: mt, format: uid).delete
          end
        end
        db[:mimetypes].where(format: uid).select_map(:mimetype) || []
      end

      def mimetypes=(value)
        mimetypes(value)
      end

      def extensions(value = nil)
        if value
          current_values = db[:extensions].where(format: uid).get(:extension) || []
          new_values = [value].flatten.uniq
          to_add = new_values - current_values
          to_remove = current_values - new_values
          to_add.each do |ext|
            db[:extensions].insert(extension: ext, format: uid)
          end
          to_remove.each do |ext|
            db[:extensions].where(extension: ext, format: uid).delete
          end
        end
        db[:extensions].where(format: uid).select_map(:extension) || []
      end

      def extensions=(value)
        extensions(value)
      end

      def []=(key, value)
        case key
        when :mimetypes
          mimetypes(value)
        when :extensions
          extensions(value)
        else
          super(key, value)
        end
      end

      def [](key)
        case key
        when :mimetypes
          mimetypes
        when :extensions
          extensions
        else
          super(key)
        end
      end

      def related_format_ids
        db[:format_relations]
          .where(uid: uid)
          .to_hash_groups(%i[relation_type source], :related_format)
          .merge(
            db[:mimetypes]
              .where(format: uid)
              .to_hash_groups(:mimetype, :format)
              .transform_keys { |x| ['related_by_mimetype', x] },
            db[:extensions]
              .where(format: uid)
              .to_hash_groups(:extension, :format)
              .transform_keys { |x| ['related_by_extension', x] }
          )
      end

      def relations
        related_format_ids.transform_values do |format_ids|
          format_ids.map { |uid| Teneo::FormatLibrary::Format[uid] }
        end
      end

      def add_relation(related_format:, relation_type:, source:, inverse_relation_type: nil, source_version: nil)
        related_format = related_format.uid if related_format.is_a?(Teneo::FormatLibrary::Format)
        db[:format_relations].where(
          uid: uid,
          related_format: related_format,
          relation_type: relation_type,
          source: source
        ).update(
          source_version: source_version
        ) == 1 || db[:format_relations].insert(
          uid: uid,
          related_format: related_format,
          relation_type: relation_type,
          source: source,
          source_version: source_version
        )

        return unless inverse_relation_type

        db[:format_relations].where(
          uid: related_format,
          related_format: uid,
          relation_type: inverse_relation_type,
          source: source
        ).update(
          source_version: source_version
        ) == 1 || db[:format_relations].insert(
          uid: related_format,
          related_format: uid,
          relation_type: inverse_relation_type,
          source: source,
          source_version: source_version
        )
      end

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

      # Overrides the default from_hash method to handle mimetypes, extensions, and relations.
      #
      # @param data [Hash] the hash of attributes
      # @param key [Symbol, nil] an optional key for lookup existence; default: :uid
      # @param block [Proc] an optional block to execute after the format is created
      # @return [Teneo::FormatLibrary::Format] the created Format instance
      def self.from_hash(data:, key: nil, &block)
        mimetypes = data.delete(:mimetypes) || []
        extensions = data.delete(:extensions) || []
        relations = data.delete(:relations) || []
        key ||= :uid
        fmt = super(data: data, key: key, &block)

        fmt.mimetypes = mimetypes
        fmt.extensions = extensions

        relations.each do |relation|
          fmt.add_relation(
            related_format: relation[:related_format],
            relation_type: relation[:relation_type],
            inverse_relation_type: relation[:inverse_relation_type],
            source: relation[:source],
            source_version: relation[:source_version]
          )
        end

        fmt
      end

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
        db[:formats].where(source: 'PRONOM').exclude(source_version: version).delete

        # No foreign key constraints on the format_relations table; delete any old relations
        db[:format_relations].where(source: 'PRONOM').exclude(source_version: version).delete
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
          db.transaction do
            fmt = Teneo::FormatLibrary::Format.create(
              uid: file_format['PUID'],
              name: file_format['Name'],
              version: file_format['Version'],
              source: 'PRONOM',
              source_version: version,
              created_at: date,
              url: "https://www.nationalarchives.gov.uk/PRONOM/#{file_format['PUID']}"
            )
            fmt.mimetypes = file_format['MIMEType']&.split(',')&.map(&:strip) || []
            fmt.extensions = file_format.xpath('Extension').map do |extension|
              extension.inner_text.strip
            end.compact
            xpath_to_array(element: file_format, xpath: 'HasPriorityOverFileFormatID').each do |related_uid|
              related_format = doc.xpath("/FFSignatureFile/FileFormatCollection/FileFormat[@ID='#{related_uid}']").first
              fmt.add_relation(
                related_format: related_format['PUID'],
                relation_type: 'has_priority_over',
                inverse_relation_type: 'has_lower_priority_than',
                source: 'PRONOM',
                source_version: version
              )
            end
          end
        end
      end

      # Download the latest FDD XML file from the Library of Congress site
      def self.load_loc_signatures
        OpenURI.open_uri('https://www.loc.gov/preservation/digital/formats/fddXML.zip') do |url|
          Zip::File.open_buffer(url) do |zf|
            zf.each do |f|
              next unless f.ftype == :file && f.name =~ %r{^fddXML/fdd\d+\.xml$}

              db.transaction do
                fdd_parse(f.get_input_stream)
              end
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
        format = {
          source: 'LOC',
          source_version: date,
          created_at: date,
          uid: root['id'],
          name: root['titleName'],
          url: "https://www.loc.gov/preservation/digital/formats/fdd/#{root['id']}.shtml"
        }
        fmt = from_hash(data: format)
        sigs = root.xpath('/fdd:FDD/fdd:fileTypeSignifiers/fdd:signifiersGroup')
        fmt.mimetypes = xpath_to_array(element: sigs, xpath: 'fdd:internetMediaType/fdd:sigValues/fdd:sigValue')
        fmt.extensions = xpath_to_array(element: sigs, xpath: 'fdd:fileExtension/fdd:sigValues/fdd:sigValue')
        xpath_to_array(element: sigs, xpath: 'fdd:other/fdd:tag/fdd:values/fdd:sigValues/fdd:sigValue').each do |related_uid|
          fmt.add_relation(
            related_format: related_uid,
            relation_type: 'related_format',
            source: fmt.source,
            source_version: fmt.source_version,
            inverse_relation_type: 'related_format'
          )
        end
        root.xpath('/fdd:FDD/fdd:identificationAndDescription/fdd:relationships/fdd:relationship').each do |relationship|
          relationship_type = xpath_to_array(element: relationship, xpath: 'fdd:typeOfRelationship').first
          xpath_to_array(element: relationship, xpath: 'fdd:relatedTo/fdd:id').each do |related_uid|
            fmt.add_relation(
              related_format: related_uid,
              relation_type: relationship_type.tr(' ', '_').downcase,
              source: fmt.source,
              source_version: fmt.source_version
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
