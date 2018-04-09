FROM symbols/minimal-ruby:2.5.1

MAINTAINER Simon Detheridge <simon@widgit.com>

COPY Gemfile Gemfile.lock config.yml /app/
COPY lib /app/lib
COPY bin /app/bin

RUN apk add --update --no-cache build-base && \
    cd /app && \
    bundle install --without=development && \
    apk del build-base && \
    rm -rf /var/cache/apk/*

WORKDIR /app
ENTRYPOINT ["/usr/local/rvm/wrappers/default/bundle", "exec"]
CMD ["bin/monitor_buildkite"]
