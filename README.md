# Teneo::FormatLibrary

## The Format Library

The Teneo Format Library is a registry of formats and tags that support the file format services for the Teneo tools and services. This repository provides the database models, REST interface and tools for the Teneo Format Library.

## Installation

The easiest way to install the Format Library is to use the Docker image. The image only contains the REST interface and the code to interact with the database. A postgres database needs to be provided in a compose file like the example below.

```yaml
services:
  db:
    image: postgres:17-alpine
    init: true
    shm_size: 128mb
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - pgdata:/var/lib/postgresql/data

  app:
    image: ${APP_IMAGE}:${APP_VERSION}
    ports:
      - ${PUBLIC_PORT}:3000
    environment:
      DB_ADAPTER: postgres
      DB_HOST: db
      DB_PORT: 5432
      DB_USER: ${DB_USER}
      DB_PASSWORD: ${DB_PASSWORD}
      DB_NAME: ${DB_NAME}
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
```

Start the database and application containers with:

```bash
docker compose up -d
```

The database also needs to be initialized. This can be done by the app container and needs two steps:

```bash
docker compose exec app rake teneo:format_library:migrate
docker compose exec app rake teneo:format_library:seed
```

The last command will fill the database with format information from PRONOM and the Library of Congres web sites. If you want to load your tags and local formats, you can do so:

First make sure that you mount a volume in the app container where the seed files for your tags and formats are located. They should be formatted as YAML files. You can use our seed files included in this repository as reference. They are located in the `/seeds/kuleuven/data` folder. There may be other organisation's seed files under the  `/seeds` folder as well.

Then you must add environment variables to the container:

- `FORMAT_LIBRARY_SEEDS_FORMAT_DIR` must point at the mounted location of a folder containing one or more format YAML files.
- `FORMAT_LIBRARY_SEEDS_TAG_DIR` must point at the mounted location of a folder containing one or more tag YAML files.

The format YAML files will be read first, so that you can reference the format uid's in the tag YAML files.

## Usage

The REST API will be available in the path `library/api/rest/v1`. In the subpath `/openapi/json` or `/openapi/yaml` there is an OpenAPI specification of the REST API. It can be used in OpenAPI compatible viewers like SwaggerUI.
