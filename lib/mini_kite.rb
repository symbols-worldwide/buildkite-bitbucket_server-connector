# frozen_string_literal: true

require 'buildkit'
require 'app_logger'

# Wrapper for buildkit with convenience methods for the things we need
class MiniKite
  def initialize(config, log)
    @log = log
    @config = config

    build_middleware
    @buildkite = Buildkit.new(token: @config['token'])
  end

  def all_pipelines
    @buildkite.pipelines(@config['organization'])
  end

  def all_builds_since(time)
    @log.debug("Getting all builds since #{time.iso8601}")
    @buildkite.organization_builds(@config['organization'],
                                   created_from: time.iso8601) +
      @buildkite.organization_builds(@config['organization'],
                                     finished_from: time.iso8601)
  end

  def builds_since(pipeline, time)
    @log.debug("Getting builds for #{pipeline} since #{time.iso8601}")
    @buildkite.pipeline_builds(@config['organization'], pipeline,
                               created_from: time.iso8601) +
      @buildkite.pipeline_builds(@config['organization'], pipeline,
                                 finished_from: time.iso8601)
  end

  private

  def build_middleware
    Buildkit::Client.build_middleware do |builder|
      builder.response :logger, @log, bodies: true
    end
  end
end
