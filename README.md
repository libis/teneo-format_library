# Teneo::FormatLibrary

This is the repository for the `teneo-format_library` gem.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add teneo-format_library

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install teneo-format_library

## The Format Library

The Teneo Format Library is a registry of formats and tags that support the file format services for the Teneo tools and services. This gem provides the database storage and interface for the Teneo Format Library.

## Models
The database storage is based on the [Sequel](https://rubygems.org/gems/sequel) gem and this gem provides [Models](https://sequel.jeremyevans.net/rdoc/classes/Sequel/Model.html) and [Datasets](https://sequel.jeremyevans.net/rdoc/classes/Sequel/Dataset.html) for the database objects.

### Format

The Format model represents the file format information stored in the `formats` database table. A format has a unique identifier, descriptive name and optional version. Most formats also contain data about their provenance (`source` and `source_version`), the associated MIME types (`mimetypes`), preferred extensions (`extensions`) and their relationships with other formats (`parent_format` and `related_formats`). Whenever possible a link to the source documentation is added (`url`).

Additional information about the format can be available in the `properties` field. This is a structured JSON field which is also indexed and therefore can be used in searches and filters. It is intended for future enrichments of the file formats' data.

A Format model instance has some convenience methods:
- `all_tags_hash`: Returns a Hash with all tags associated with this format, directly or indirectly
- `all_tags_ds`: Returns a dataset of all tags associated with this format, directly or indirectly

The Format model class these methods:
- `load_pronom_signatures`: downloads the latest PRONOM signatures from the PRONOM website and loads them into the database, updating/appending the current PRONOM signatures
- `load_loc_signatures`: downloads the latest LOC (Library of Congress) signatures from the website and loads them into the database.

### Tag

An important addition to the file formats are the Tags. Tags can be associated to one or more Formats, but can also be associated with other Tags, thus creating a hierarchy of Tags and Formats. The relationships between Formats and Tags and between Tags are both many-to-many. This implicates that a Format can be tagged by multiple Tags and Tags can be tagged by multiple Tags themselves.

The Tag is identified by a unique short text (`tag`) and it also has a more descriptive name (`name`). Each Tag has a `profile` field that allows filtering the Tags based on its usage, domain or anything else that one wants to differentiate the Tags from.

Addtional information for a Tag is stored in two fields: `properties` and `info`. Both a structured JSON fields, but the `properties` field is indexed and can be used for searching and/or filtering, while the `info` field is not indexed and is intended for less structured data like links to documentation, notes, etc.

The Tag model instance has the following methods:
- `descendants_hash`: Creates a hash of tags that are descendants of this tag
- `ancestors_hash`: Creates a hash of tags that are ancestors of this tag
- `descendants_ds`: Returns a dataset of all descendant tags of this tag
- `ancestors_ds`: Returns a dataset of all ancestor tags of this tag
- `tree_ds`: Returns a dataset of the tree of tag descendants
- `tree_structure`: Builds a nested hash structure from the tag tree
- `tree_formats`: Builds a nested hash structure from the tag tree with formats
- `all_formats_hash`: Returns a hash with all formats that are associated with this tag or any of its descendant tags
- `all_formats_ds`: Returns a dataset of all formats that are associated with this tag or any of its descendant tags