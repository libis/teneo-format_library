ARG RUBY_IMAGE
ARG RUBY_VERSION
FROM ${RUBY_IMAGE:-ruby}:${RUBY_VERSION:-3.4.1}

USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libpq-dev \
    && \
    rm -rf /var/lib/apt/lists/*

USER app
ENV PATH=/app/bin:$PATH
