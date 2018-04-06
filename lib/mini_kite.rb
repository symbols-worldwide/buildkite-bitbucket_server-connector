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

  def builds_in_state(pipeline, state)
    states = buildkite_states_for_bitbucket(state)
    update_window = Time.now - @config['update_window'].to_i * 3600
    @buildkite.pipeline_builds(@config['organization'], pipeline,
                               state: states,
                               created_from: update_window.iso8601)
  end

  private

  def build_middleware
    Buildkit::Client.build_middleware do |builder|
      builder.response :logger, @log, bodies: true
    end
  end

  def buildkite_states_for_bitbucket(state)
    case state
    when 'INPROGRESS'
      %w[running scheduled blocked canceling]
    when 'FAILED'
      %w[failed canceled]
    when 'SUCCESSFUL'
      %w[passed]
    end
  end
end
