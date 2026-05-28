ARG RUBY_IMAGE
ARG RUBY_VERSION

FROM ${RUBY_IMAGE:-ruby}:${RUBY_VERSION:-latest}

USER root
RUN apt-get update -qq \
    && apt-get install -qqy --no-install-recommends \
        libpq-dev \
        postgresql-client \
        postgresql-contrib \
    && rm -rf /var/lib/apt/lists/*

USER app
ENV PATH=/app/bin:$PATH
