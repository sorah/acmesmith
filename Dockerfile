FROM ghcr.io/sorah-rbpkg/ruby:3.4-dev as builder

#RUN apt-get update \
#    && apt-get install -y libmysqlclient-dev git-core \
#    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile /app/
COPY Gemfile.lock /app/
COPY acmesmith.gemspec /app/
RUN sed -i -e 's|Acmesmith::VERSION|"0.0.0"|g' -e '/^require.*acmesmith.version/d' -e '/`git/d' acmesmith.gemspec

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends libssl-dev

RUN bundle install --path /gems --jobs 100 --without development

FROM ghcr.io/sorah-rbpkg/ruby:3.4

WORKDIR /app
COPY . /app/
COPY --from=builder /gems /gems
COPY --from=builder /app/.bundle /app/.bundle
COPY --from=builder /app/Gemfile* /app/
COPY --from=builder /app/acmesmith.gemspec /app/

ENTRYPOINT ["bundle", "exec", "bin/acmesmith"]

