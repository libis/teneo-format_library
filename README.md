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

The Format model class provides these methods, used for loading the format descriptions:
- `load_pronom_signatures`: downloads the latest PRONOM signatures from the PRONOM website and loads them into the database
- `load_loc_signatures`: downloads the latest LOC (Library of Congress) signatures from the website and loads them into the database

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

### Datasets vs Hashes

The `*_ds` methods return a Dataset and the `*_hash` methods return a Hash. There is an important difference between both versions.

The Hash variants return a Hash that contains references to Model instances. You can call any of the Model instance methods on these.

The Dataset variants return a Dataset, which in essence is a SQL statement waiting to be executed. Only when operations are called that need to retrieve data (like `count` or `all`), the SQL will be executed. But it is also possible to call methods that update the SQL statement without executing, like `where` and `select` operators.

i.o.w. Depending on how you want to process the result, you should choose the method variant wisely. 

Some examples:

```ruby
# Get the labels of all the format tags for a given format.

fmt = Teneo::FormatLibrary::Format['fmt/44']
# => #<Teneo::FormatLibrary::Format @values={uid: "fmt/44", name: "JPEG File Interchange Format", version: "1.02", source: "PRONOM", source_version: "120", url: "https://www.nationalarchives.gov.uk/PRONOM/fmt/44", mimetypes: ["image/jpeg"], extensions: ["jfi", "jfif", "jif", ...

# First, using the _hash variant
fmt.all_tags_hash
# => {"JPG" => #<Teneo::FormatLibrary::Tag @values={tag: "JPG", name: "Joint Photographic Experts Group (JPEG) images", profile: "teneo", properties: nil, info: nil}>, "IMAGE" => #<Teneo::FormatLibrary::Tag @values={tag: "IMAGE", name: "Common image formats", profile: "teneo", properties: nil, info: nil}>, "WEB_IMAGE" => #<Teneo::FormatLibrary::Tag @values={tag: "WEB_IMAGE", name: "Web safe image formats", profile: "web", properties: nil, info: nil}>}
fmt.all_tags_hash.keys
# => ["JPG", "IMAGE", "WEB_IMAGE"]

# Next, using the _ds variant
fmt.all_tags_ds
# => #<Sequel::Dataset::_Subclass: "WITH RECURSIVE \"format_tags\" AS (SELECT tags.* FROM \"tags\" INNER JOIN \"tagged_formats\" ON (\"tagged_formats\".\"tag\" = \"tags\".\"tag\") WHERE (\"tagged_formats\".\"format\" = $1) UNION ALL (SELECT \"tags\".* FROM \"tags\" INNER JOIN \"tagged_tags\" ON (\"tagged_tags\".\"parent\" = \"tags\".\"tag\") INNER JOIN \"format_tags\" ON (\"format_tags\".\"tag\" = \"tagged_tags\".\"tag\"))) CYCLE \"tag\" SET \"is_cycle\" TO true DEFAULT false USING \"path\" SELECT * FROM \"format_tags\"; [\"fmt/44\"]">
fmt.all_tags_ds.select_map(:tag)
# => ["JPG", "IMAGE", "WEB_IMAGE"]

# Same, but get the tag's name
fmt.all_tags_hash.map {|_,v| v.name}
# => ["Joint Photographic Experts Group (JPEG) images", "Common image formats", "Web safe image formats"]
fmt.all_tags_ds.select_map(:name)
#=> ["Joint Photographic Experts Group (JPEG) images", "Common image formats", "Web safe image formats"]
```

```ruby
# Given a tag, find its formats with version '2.0' and return the format names

tag = Teneo::FormatLibrary::Tag['PDF']
# => #<Teneo::FormatLibrary::Tag @values={tag: "PDF", name: "Adobe Portable Document Format (PDF)", profile: "teneo", properties: nil, info: nil}>

# First, using _hash
tag.all_formats_hash.size
# => 67

tag.all_formats_hash.select {|_,v| v.version == "2.0"}.map {|_,v| v.name}
# => ["Hypertext Markup Language", "Microsoft Word for Windows Document", "PDF 2.0 - Portable Document Format"]

# This time using the _ds variant
tag.all_formats_ds.where(version: '2.0').select_map(:name)
# => ["PDF 2.0 - Portable Document Format", "Microsoft Word for Windows Document", "Hypertext Markup Language"]
```

As in this last example, the _ds variants are more efficient when only a small selection of the data is required. In this case only 3 out of all 67 of the tags are selected and only their names are required. When using the _hash variant all the data of the 67 tags are retrieved from the database and the code then filters out the data. With the _ds variant on the other hand, the database query only retrieves the names of the 3 tags. The result set of a Dataset is an array of hashes and needs a bit more processing in the code, but it needs to operate on way less data.

The most important difference between the `*_hash` and `*_ds` methods is that the recursive operations are perfomed in the code for the `_hash` variants, but are performed by the database for the `_ds` variants.

### Infinite loops
The tag linking supports creating infinite loops. It is not considered to be a good practice, but still both the `_hash` and `_ds` variants have a protection against these infinite loops. The `_hash` variants do this by keeping track of the collected items, but the `_ds` variants use the [`CYCLE`](https://www.postgresql.org/docs/current/queries-with.html#QUERIES-WITH-CYCLE) database feature. As a consequence, the results of the Dataset will contain two extra fields:
- `is_cycle` will contain false, unless an infinite loop is detected
- `path` contains the hierarchical path followed to reach this item

```ruby
tag = Teneo::FormatLibrary::Tag['ROOT']
# => #<Teneo::FormatLibrary::Tag @values={tag: "ROOT", name: "Root tag", profile: "infinite_loop", properties: nil, info: nil}>

tag.tree_ds.all
# => 
# [{tag: "ROOT", parent: nil, is_cycle: false, path: "{(ROOT)}"},
#  {tag: "CHILD1", parent: "ROOT", is_cycle: false, path: "{(ROOT),(CHILD1)}"},
#  {tag: "CHILD2", parent: "ROOT", is_cycle: false, path: "{(ROOT),(CHILD2)}"},
#  {tag: "GRANDCHILD1", parent: "CHILD1", is_cycle: false, path: "{(ROOT),(CHILD1),(GRANDCHILD1)}"},
#  {tag: "GRANDCHILD2", parent: "CHILD2", is_cycle: false, path: "{(ROOT),(CHILD2),(GRANDCHILD2)}"},
#  {tag: "ROOT", parent: "GRANDCHILD1", is_cycle: true, path: "{(ROOT),(CHILD1),(GRANDCHILD1),(ROOT)}"}]
#                                       ==============

tag = Teneo::FormatLibrary::Tag['PDF']
# => #<Teneo::FormatLibrary::Tag @values={tag: "PDF", name: "Adobe Portable Document Format (PDF)", profile: "teneo", properties: nil, info: nil}>

tag.ancestors_ds.all
# => 
# [{tag: "PDF", name: "Adobe Portable Document Format (PDF)", profile: "teneo", properties: nil, info: nil, is_cycle: false, path: "{(PDF)}"},
#  {tag: "FORMATTED_TEXT", name: "Formatted text", profile: "teneo", properties: nil, info: nil, is_cycle: false, path: "{(PDF),(FORMATTED_TEXT)}"},
#  {tag: "WEB_TEXT", name: "Web safe text formats", profile: "web", properties: nil, info: nil, is_cycle: false, path: "{(PDF),(WEB_TEXT)}"},
#  {tag: "TEXT", name: "Common text formats", profile: "teneo", properties: nil, info: nil, is_cycle: false, path: "{(PDF),(FORMATTED_TEXT),(TEXT)}"}]

tag.descendants_ds.all
# => 
# [{tag: "PDF", name: "Adobe Portable Document Format (PDF)", profile: "teneo", properties: nil, info: nil, is_cycle: false, path: "{(PDF)}"},
#  {tag: "PDFA", name: "Adobe Portable Document Format for Archives (PDFA)", profile: "teneo", properties: nil, info: nil, is_cycle: false, path: "{(PDF),(PDFA)}"},
#  {tag: "PDFX", name: "Acrobat PDF/X - Portable Document Format", profile: "teneo", properties: nil, info: nil, is_cycle: false, path: "{(PDF),(PDFX)}"},
#  {tag: "PDFE", name: "Acrobat PDF/E - Portable Document Format for Engineering", profile: "teneo", properties: nil, info: nil, is_cycle: false, path: "{(PDF),(PDFE)}"}]
```
## Usage

The gem can be used like so:
```ruby
require 'teneo/format_library'
```

You will have access to the Format and Tag models:
```ruby
fmt = ::Teneo::FormatLibrary::Format['fmt/44']
# => #<Teneo::FormatLibrary::Format @values={uid: "fmt/44", ...
fmt.uid
# => "fmt/44"
fmt.name
# => "JPEG File Interchange Format"
fmt.version
# => "1.02"
fmt.source
# => "PRONOM"
fmt.url
# => "https://www.nationalarchives.gov.uk/PRONOM/fmt/44"
fmt.mimetypes
# => ["image/jpeg"]
fmt.extensions
# => ["jfi", "jfif", "jif", "jpe", "jpeg", "jpg"]
fmt.tags
# => [#<Teneo::FormatLibrary::Tag @values={tag: "JPG", name: "Joint Photographic Experts Group (JPEG) images", profile: "teneo", properties: nil, info: nil}>]
fmt.tags.map(&:tag)
# => ["JPG"]
fmt.all_tags_hash
# => {"JPG" => #<Teneo::FormatLibrary::Tag @values={tag: "JPG", name: "Joint Photographic Experts Group (JPEG) images", profile: "teneo", properties: nil, info: nil}>, "IMAGE" => #<Teneo::FormatLibrary::Tag @values={tag: "IMAGE", name: "Common image formats", profile: "teneo", properties: nil, info: nil}>, "WEB_IMAGE" => #<Teneo::FormatLibrary::Tag @values={tag: "WEB_IMAGE", name: "Web safe image formats", profile: "web", properties: nil, info: nil}>}
fmt.all_tags_ds
# => #<Sequel::Dataset::_Subclass: "WITH RECURSIVE \"format_tags\" AS (SELECT tags.* FROM \"tags\" INNER JOIN \"tagged_formats\" ON (\"tagged_formats\".\"tag\" = \"tags\".\"tag\") WHERE (\"tagged_formats\".\"format\" = $1) UNION ALL (SELECT tags.* FROM \"tags\" INNER JOIN \"tagged_tags\" ON (\"tagged_tags\".\"parent\" = \"tags\".\"tag\") INNER JOIN \"format_tags\" ON (\"format_tags\".\"tag\" = \"tagged_tags\".\"tag\"))) SELECT * FROM \"format_tags\"; [\"fmt/44\"]">
fmt.all_tags_ds.all
# => [{tag: "JPG", name: "Joint Photographic Experts Group (JPEG) images", profile: "teneo", properties: nil, info: nil},{tag: "IMAGE", name: "Common image formats", profile: "teneo", properties: nil, info: nil},{tag: "WEB_IMAGE", name: "Web safe image formats", profile: "web", properties: nil, info: nil}]
fmt.all_tags_ds.where(profile: 'web').all
# => [{tag: "WEB_IMAGE", name: "Web safe image formats", profile: "web", properties: nil, info: nil}]
```

## Initialization
The format library database needs to be created and filled with data. The gem can assist with that.

### Database configuration

It is up to you to provide a database server with PostgreSQL installed and running. A user (DB role) should be created that has owner rights on the database.

The gem does need to know the database configuration in order to connect to the database. It relies on the following environment variables and it provides some reasonable defaults.

|Variable name|default value|description|
-----------------------------------------
|`DB_HOST`|localhost|name or IP address of the database server|
|`DB_PORT`|5432|port number where PostgreSQL is listening on|
|`DB_NAME`|teneo|database name|
|`DB_USER`|teneo|database account name|
|`DB_PASSWORD`|teneo|database account password|
|`DB_MAX_CONNECTIONS`|10|maximum number of concurrent connections to the database|

### Migrating and seeding the database

To set up the database, the gem provides migration and seed scripts and Rake tasks that execute them.

#### Migration

The task `teneo:format_library:migrate` runs the migration scripts that come with the gem. There should be no need to change them, but if you want to inspect them, they are located in the gem's `db/migrations` directory.

If you want to experiment with changes to these scripts, you can tell the task to use your own set of scripts by setting the `FORMAT_LIBRARY_MIGRATIONS_DIR` environment variable. Needless to say that you are on your own if you do so.

#### Seeding

The task `teneo:format_library:seed` runs the seeding scripts that come with the gem. These default seeds will load the PRONOM and LOC format signatures and a few extra formats. They also load a default set of tags and a sample tag hierarchy.

If you want to skip the extra formats and supply your own set the `FORMAT_LIBRARY_SEEDS_FORMAT_DIR` environment variable to a directory that contain your .yml files with your own formats. You can use the files in the gem's `db/seeds/data/formats` directory as a sample.

If you want to supply your own set of tags to be seeded, set the environment variable `FORMAT_LIBRARY_SEEDS_TAG_DIR` to a directory with your own set of .yml files for your own tags. Use the files in the gem's directory `db/seeds/data/tags` for inspiration.

If you want to skip loading any of the default formats and tags, you can supply your own seed scripts by setting the `FORMAT_LIBRARY_SEEDS_DIR` environment variable to a directory with your own seed scripts. Have a look at scripts in the gem's `db/seeds` directory for the syntax of the seed scripts or consult the [sequel-seed plugin documentation](https://github.com/earaujoassis/sequel-seed).

#### Enabling the Rake tasks in your Rakefile

In your Rakefile, include the following:

```ruby
require 'teneo/format_library'

spec = Gem::Specification.find_by_name 'teneo-format_library'
rakefile = "#{spec.gem_dir}/lib/teneo/format_library/Rakefile"
load rakefile
```

You will now be able to use the tasks:

```ruby
rake teneo:format_library:migrate
# Connecting to database ...
# >> Connected to database! <<
# Run migrations
# ==============
# Creating table 'formats'...
# Creating table 'tags'...
# Creating table 'tagged_formats'...
# Creating table 'tagged_tags'...
```

```ruby
export FORMAT_LIBRARY_SEEDS_FORMAT_DIR=/my/seeds/formats
export FORMAT_LIBRARY_SEEDS_TAG_DIR=/my/seeds/tags
rake teneo:format_library:seed
# Connecting to database ...
# >>> Connected to database! <<<
# Run seeds
# =========
# Loading PRONOM Signatures data ...
# Loading LOC Signatures data ...
# Loading extra formats data ...
# ... from my_formats.yml ...
# Loading Format tags ...
# ... from my_tags.yml ...
```

## Development

After checking out the repo, make sure you have `docker` and `docker compose` installed on your machine. There is a `Makefile` available in the root dir to support you with most common tasks. All the tasks will be executed in a container to have the least possible requirements for the development machine.

The following Makefile targets are available:

- `install`: install the necessary gems
- `update`: update the gems to the latest version
- `release`: release a new version of the gem
- `up`: start the docker containers with PostgreSQL and PgAdmin
- `down`: stop the docker containers
- `clear`: stops the docker containers and clears the database
- `build`: build the image requried for running targets below
- `migrate`: run the migration scripts
- `seed`: run the seed scripts
- `test`: run the tests
- `console`: run an irb console, completely initialized
- `tool`: run the tool container with a bare Bash shell

There is a `compose.yml` file that configures 3 containers:
- `teneo-db`: the container running the PostgreSQL database
- `teneo-db_admin`: a PgAdmin container to inspect the database
- `teneo-db_tool`: a container for running the make targets

The first two containers are spun up and closed when `make up` and `make down` are called. The last container is started manually by the make targets.

The compose file also configures two networks:
- `teneo_app_net`: network for frontend facing container
- `teneo_db_net`: network for database connections

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `make release`, which will create a git tag for the version, push git commits and the created tag, update the `CHANGELOG.md` and push the gem to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/libis/teneo-format_library.

## License

The gem is available as open source under the terms of the [GNU Affero General Public License](https://www.gnu.org/licenses/agpl-3.0.html).
