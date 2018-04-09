FROM symbols/minimal-ruby:2.5.1

MAINTAINER Simon Detheridge <simon@widgit.com>

COPY . /app

RUN apk add --update --no-cache build-base && \
    cd /app && \
    bundle install --without=development && \
    apk del build-base && \
    rm -rf /var/cache/apk/*

WORKDIR /app
ENTRYPOINT ["/usr/local/rvm/wrappers/default/bundle", "exec"]
CMD ["bin/monitor_buildkite"]
