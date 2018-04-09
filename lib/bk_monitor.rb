# frozen_string_literal: true

require 'mini_bucket'
require 'mini_kite'
require 'git_clone_url'
require 'snitcher'

# Monitors buildkite and writes build status to bitbucket
class BkMonitor
  attr_accessor :log

  def initialize(config)
    @log = Logger.new(STDOUT)
    @bitbucket = MiniBucket.new(config['bitbucket'], log)
    @buildkite = MiniKite.new(config['buildkite'], log)
    @config = config['monitor']
    @snitch = config['dms']['snitch_id'].to_s
  end

  # runs a loop to monitor buildkite for new builds and report to bitbucket
  def start
    @log.warn 'Not snitching due to missing snitch id' if @snitch == ''

    loop do
      report_builds
      snitch

      sleep @config['polling_interval'].to_i
    end
  end

  # reports buildkite builds to bitbucket
  def report_builds
    t = Time.now

    apply_build_statuses

    # reset within 1 cycle in case of clock drift
    @time_since = t - @config['polling_interval'].to_i
  end

  private

  # matches buildkite pipelines with bitbucket repositories and returns matches
  def matched_pipelines
    repos = @bitbucket.all_repos
    pipelines = @buildkite.all_pipelines
    r = {}

    pipelines.each do |pipeline|
      repo = repo_for_pipeline(pipeline, repos)
      r[pipeline[:slug]] = repo if repo
    end

    r
  end

  def repo_for_pipeline(pipeline, repos)
    repos.find do |r|
      r[:links][:clone].any? do |link|
        git_urls_match(link[:href], pipeline[:repository])
      end
    end
  end

  def git_urls_match(left, right)
    a = GitCloneUrl.parse(left)
    b = GitCloneUrl.parse(right)

    a.host == b.host && a.path.sub(/\.git$/, '') == b.path.sub(/\.git$/, '')
  end

  # write the status of builds from `pipeline` to bitbucket
  def apply_build_statuses
    @buildkite.all_builds_since(search_start_time).each do |build|
      apply_build_state_for_build(
        build,
        bitbucket_state_for_buildkite_build(build)
      )
    end
  rescue StandardError => e
    @log.exception(e)
  end

  # write the status of a build to bitbucket
  def apply_build_state_for_build(build, state)
    existing_state = @bitbucket.build_state_for_commit(build[:commit],
                                                       build[:pipeline][:id])

    return if existing_state == state

    @log.info("Setting build state #{state} for #{build[:commit]}")
    @bitbucket.set_build_state_for_commit(build[:commit],
                                          state,
                                          build[:pipeline][:id],
                                          options_from_build(build))
  end

  def options_from_build(build)
    {
      name: "Buildkite build #{build[:number]}",
      url: build[:web_url],
      description: build[:message]
    }
  end

  def snitch
    Snitcher.snitch(@snitch) if @snitch != ''
  end

  def bitbucket_state_for_buildkite_build(build)
    case build[:state]
    when 'running', 'scheduled', 'blocked', 'canceling'
      'INPROGRESS'
    when 'failed', 'canceled'
      'FAILED'
    when 'passed'
      'SUCCESSFUL'
    end
  end

  def search_start_time
    @time_since || Time.now - @config['initial_search_time'].to_i * 60 * 60
  end
end
