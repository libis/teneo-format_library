ARG RUBY_VERSION=3.4.9
ARG RUBY_OS_VERSION=slim
FROM ruby:${RUBY_VERSION}-${RUBY_OS_VERSION} AS gem_base

# Silence apt
RUN dpkg-reconfigure debconf --frontend=noninteractive

# Install common packages
RUN apt-get update -qq \
 && apt-get install -qqy --no-install-recommends \
        build-essential \
        gnupg2 \
        curl \
        less \
        git \
        wget \
        libsqlite3-dev \
        vim \
        libyaml-dev \
        libpq-dev \
        postgresql-client \
 && apt-get -qqy upgrade \
 && apt-get -qqy autoremove \
 && apt-get clean \
 && rm -fr /var/cache/apt/archives/* \
 && rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp* \
 && truncate -s 0 /var/log/*log

# Copy Entrypoint script
COPY start.sh /usr/local/bin/start.sh
RUN chmod 755 /usr/local/bin/start.sh

# Upgrade RubyGems and install required Bundler version
ARG BUNDLER_VERSION=4.0.12
RUN gem update --system && \
    gem install bundler:${BUNDLER_VERSION}

ENTRYPOINT [ "/usr/local/bin/start.sh" ]
CMD [ "irb" ]

ARG USER_ID=1000
ARG GROUP_ID=1000
FROM gem_base AS gem_tools

ARG USER_ID
ARG GROUP_ID
RUN groupadd -g ${GROUP_ID:-1000} app \
    && useradd -rm -d /app -s /bin/bash -g app -u ${USER_ID:-1000} app

USER app
WORKDIR /app

# Location of the installed gems
ENV GEMS_PATH=/app/vendor/bundle

# Prepare ruby environment
ENV LANG=C.UTF-8 \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    BUNDLE_PATH=${GEMS_PATH}\
    RUBY_ENV=development

ARG GEM_VERSION=0.1
FROM gem_tools AS gem_test

ARG GEM_VERSION
ENV GEM_VERSION=${GEM_VERSION}

COPY teneo-format_library-${GEM_VERSION}.gem .
COPY spec ./spec/
COPY Rakefile.test Rakefile

COPY --chown=app:app Gemfile.test ./Gemfile
RUN gem unpack teneo-format_library-${GEM_VERSION}.gem && \
    bundle install

# Run tests
CMD ["rake", "spec"]

FROM gem_test AS api

COPY --chown=app:app api/Gemfile ./api/Gemfile
COPY --chown=app:app api/ ./api/

WORKDIR /app/api

RUN bundle install

EXPOSE 3000
CMD ["puma", "-p", "3000"]

FROM gem_test AS grpc

COPY --chown=app:app api/Gemfile ./api/Gemfile
COPY --chown=app:app api/ ./api/
COPY --chown=app:app api/grpc/ ./grpc/

WORKDIR /app

RUN bundle install

EXPOSE 50051
CMD ["ruby", "grpc/server.rb"]
