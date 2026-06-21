ARG RUBY_VERSION=1
ARG OS_VERSION=null
ARG BUNDLER_VERSION=1

FROM ruby:${RUBY_VERSION}-${OS_VERSION}

# Silence apt
RUN dpkg-reconfigure debconf --frontend=noninteractive

# Install common packages
RUN apt-get update -qq \
 && apt-get install -qqy --no-install-recommends \
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
ARG BUNDLER_VERSION
RUN gem update --system && \
    gem install bundler:${BUNDLER_VERSION}

ENTRYPOINT [ "/usr/local/bin/start.sh" ]
CMD [ "irb" ]