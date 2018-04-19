# Buildkite -> Butbucket Server Connector

**The Problem:** You want to use Buildkite and you have your code on a Bitbucket
Server instance and you want build status reports in your pull requests. Also, 
Bitbucket is quite possibly behind your firewall so it's not that easy for
Buildkite to talk to it.

This is a moderately ugly workaround that:

* Polls Buildkite for newly-created or newly-finished builds
* Reads the states of these builds
* Tells Bitbucket about the build state for the affected commits

Efforts have been made to only poll for changes since the last request, so it
shouldn't bee too talkative, despite having to poll.

## Config required

You'll need the following things:

* A buildkite API token
* The buildkite organization slug that you're interested in
* A bitbucket username and password with write access to the necessary projects
* The URL of your bitbucket server

## Running the connector

The simplest way is via Docker:

```
docker run -E BUILDKITE_API_TOKEN=asdf1234 \
           -E BUILDKITE_ORGANIZATION=acme-inc \
           -E BITBUCKET_USERNAME=roooot \
           -E BITBUCKET_PASSWORD=hunter2 \
           -E BITBUCKET_URL=https://git.acme.com/ \
           symbols/buildkite-bitbucket_server-connector
```

Alternatively, you can run the connector directly from this project using Ruby:
```
vi config.yml
bundle install
bundle exec bin/monitor-buildkite
```

`config.yml` is parsed as erb, and by default reads environment variables.

## Bonus: Dead Man's Snitch

We are fans of [Dead Man's Snitch](https://deadmanssnitch.com) for checking that
our services are alive. If you set a DMS snitch ID in the config then the
monitor will report to DMS every time it successfully checks/imports new data.

The environment variable for this is `DMS_SNITCH_ID`

## Other settings

* `MONITOR_POLLING_INTERVAL`
  * Number of seconds between polls to Buildkite for new/finished builds
  * Default: 60
* `MONITOR_INITIAL_SEARCH_TIME`
  * Number of hours to look backwards in time for builds, when running the
  monitor. It will report builds started/finished up to x hours ago. (It
  doesn't matter if builds get reported twice.)
  * Default: 168
* `MONITOR_LOG_LEVEL`
  * Output verbosity. If you set this to 'INFO' or 'DEBUG' a lot of output will
  be generated.
  * Default: 'WARN'
