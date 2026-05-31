ARG RUBY_IMAGE
ARG RUBY_VERSION

FROM ${RUBY_IMAGE:-ruby}:${RUBY_VERSION:-latest} AS tools

USER root
RUN apt-get update -qq \
    && apt-get install -qqy --no-install-recommends \
        libpq-dev \
        postgresql-client \
        postgresql-contrib \
    && rm -rf /var/lib/apt/lists/*

COPY start.sh /usr/local/bin/start.sh
RUN chmod 755 /usr/local/bin/start.sh

RUN groupadd -g ${GID:-1000} app \
    && useradd -rm -d /app -s /bin/bash -g app -u ${UID:-1000} app

USER app
WORKDIR /app

ENV BUNDLE_PATH=/app/vendor/bundle
ENV RUBY_ENV=production

FROM tools AS app

USER app:app
WORKDIR /app

COPY --chown=app:app Gemfile Gemfile.lock /app/
RUN bundle install

COPY --chown=app:app app /app/app
COPY --chown=app:app config /app/config
COPY --chown=app:app db /app/db
COPY --chown=app:app lib /app/lib

CMD ["puma", "-C", "config/puma.rb"]
