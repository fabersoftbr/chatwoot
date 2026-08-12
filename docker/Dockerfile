# pre-build stage
#
# Debian (glibc), not Alpine (musl), on purpose. Alpine forces
# `bundle config force_ruby_platform true` further down, because the
# precompiled native gems on rubygems.org target glibc and cannot run on musl.
# That made bundler compile nokogiri, pg, grpc, protobuf, ffi and friends from
# C source on every build: 45+ minutes, and grpc alone peaks at 2-4 GB RSS,
# which OOM-kills the build on a modest host. On glibc those same gems install
# as prebuilt binaries in a couple of minutes. Gemfile.lock already carries the
# x86_64-linux variants. The cost is a larger final image.
FROM node:24-slim as node
FROM ruby:3.4.4-slim AS pre-builder

ARG NODE_VERSION="24.13.0"
ARG PNPM_VERSION="10.2.0"
ENV NODE_VERSION=${NODE_VERSION}
ENV PNPM_VERSION=${PNPM_VERSION}

# ARG default to production settings
# For development docker-compose file overrides ARGS
ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT ${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=2.5.16

ARG RAILS_SERVE_STATIC_FILES=true
ENV RAILS_SERVE_STATIC_FILES ${RAILS_SERVE_STATIC_FILES}

ARG RAILS_ENV=production
ENV RAILS_ENV ${RAILS_ENV}

ARG NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider"
ENV NODE_OPTIONS ${NODE_OPTIONS}

ENV BUNDLE_PATH="/gems"

RUN apt-get update && apt-get install --no-install-recommends -y \
  openssl \
  tar \
  build-essential \
  tzdata \
  libpq-dev \
  postgresql-client \
  git \
  curl \
  xz-utils \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /var/app \
  && gem install bundler -v "$BUNDLER_VERSION"

COPY --from=node /usr/local/bin/node /usr/local/bin/
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
  && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

RUN npm install -g pnpm@${PNPM_VERSION}

RUN echo 'export PNPM_HOME="/root/.local/share/pnpm"' >> /root/.shrc \
  && echo 'export PATH="$PNPM_HOME:$PATH"' >> /root/.shrc \
  && export PNPM_HOME="/root/.local/share/pnpm" \
  && export PATH="$PNPM_HOME:$PATH" \
  && pnpm --version

# Persist the environment variables in Docker
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

WORKDIR /app

COPY Gemfile Gemfile.lock ./

# The upstream Alpine build compiled grpc, protobuf and nokogiri from source here
# to work around musl (https://github.com/googleapis/google-cloud-ruby/issues/13306
# and https://github.com/chatwoot/chatwoot/issues/4045). On glibc none of that is
# needed: bundler resolves the prebuilt x86_64-linux gems, so there is no
# force_ruby_platform and no compiler toolchain to install beyond build-essential,
# which the base layer already has. libvips stays for the image_processing gem.
RUN apt-get update && apt-get install --no-install-recommends -y libvips42 \
  && rm -rf /var/lib/apt/lists/*

# Do not install development or test gems in production
RUN if [ "$RAILS_ENV" = "production" ]; then \
  bundle config set without 'development test'; bundle install -j 4 -r 3; \
  else bundle install -j 4 -r 3; \
  fi

COPY package.json pnpm-lock.yaml ./
RUN pnpm i

COPY . /app

# creating a log directory so that image wont fail when RAILS_LOG_TO_STDOUT is false
# https://github.com/chatwoot/chatwoot/issues/701
RUN mkdir -p /app/log

# generate production assets if production environment
RUN if [ "$RAILS_ENV" = "production" ]; then \
  SECRET_KEY_BASE=precompile_placeholder RAILS_LOG_TO_STDOUT=enabled bundle exec rake assets:precompile \
  && rm -rf spec node_modules tmp/cache; \
  fi

# Generate .git_sha file with current commit hash.
# Falls back when there is no usable .git: a worktree's .git is a file pointing
# at a path that does not exist inside the container, and a tarball deploy has
# no .git at all. config/initializers/git_sha.rb just reads this file, so an
# "unknown" here costs a version string, while a failure here costs the whole
# build — after the gems and the asset precompile have already run.
RUN git rev-parse HEAD > /app/.git_sha 2>/dev/null || echo unknown > /app/.git_sha

# Remove unnecessary files
RUN rm -rf /gems/ruby/3.4.0/cache/*.gem \
  && find /gems/ruby/3.4.0/gems/ \( -name "*.c" -o -name "*.o" \) -delete \
  && rm -rf .git \
  && rm .gitignore

# final build stage
FROM ruby:3.4.4-slim

ARG NODE_VERSION="24.13.0"
ARG PNPM_VERSION="10.2.0"
ENV NODE_VERSION=${NODE_VERSION}
ENV PNPM_VERSION=${PNPM_VERSION}

ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT ${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=2.5.16

ARG EXECJS_RUNTIME="Disabled"
ENV EXECJS_RUNTIME ${EXECJS_RUNTIME}

ARG RAILS_SERVE_STATIC_FILES=true
ENV RAILS_SERVE_STATIC_FILES ${RAILS_SERVE_STATIC_FILES}

# BUNDLE_FORCE_RUBY_PLATFORM is deliberately absent: setting it here would make
# the runtime reject the prebuilt gems the pre-builder stage installed.

ARG RAILS_ENV=production
ENV RAILS_ENV ${RAILS_ENV}
ENV BUNDLE_PATH="/gems"

# No compiler in the runtime image: the gems arrive prebuilt from the pre-builder
# stage, so build-essential is dead weight here. libpq5 is the client library the
# pg gem links against at runtime (libpq-dev is only needed to compile).
RUN apt-get update && apt-get install --no-install-recommends -y \
  openssl \
  tzdata \
  libpq5 \
  postgresql-client \
  imagemagick \
  git \
  libvips42 \
  && rm -rf /var/lib/apt/lists/* \
  && gem install bundler -v "$BUNDLER_VERSION"

COPY --from=node /usr/local/bin/node /usr/local/bin/
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules

RUN if [ "$RAILS_ENV" != "production" ]; then \
  apt-get update && apt-get install --no-install-recommends -y curl \
  && rm -rf /var/lib/apt/lists/* \
  && ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
  && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
  && npm install -g pnpm@${PNPM_VERSION} \
  && pnpm --version; \
  fi

COPY --from=pre-builder /gems/ /gems/
COPY --from=pre-builder /app /app

# Copy .git_sha file from pre-builder stage
COPY --from=pre-builder /app/.git_sha /app/.git_sha

WORKDIR /app

EXPOSE 3000
