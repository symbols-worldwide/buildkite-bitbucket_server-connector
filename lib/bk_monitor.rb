# frozen_string_literal: true

require 'mini_bucket'
require 'mini_kite'
require 'git_clone_url'
require 'snitcher'

# Monitors buildkite and writes build status to bitbucket
class BkMonitor
  attr_accessor :log

  def initialize(config)
    @config = config
    @log = Logger.new(STDOUT)
    @bitbucket = MiniBucket.new(config['bitbucket'], log)
    @buildkite = MiniKite.new(config['buildkite'], log)
  end


  # runs a loop to monitor buildkite for new builds and report to bitbucket
  def start
    if @config['dms']['snitch_id'].to_s == ''
      @log.warn 'Not snitching due to missing snitch id'
    end
    loop do
      report_builds
      snitch

      sleep @config['buildkite']['polling_interval'].to_i
    end
  end

  # reports buildkite builds to bitbucket
  def report_builds
    matched_pipelines.each_pair do |pipeline, repo|
      @log.info(
        "Processing builds for pipeline: #{pipeline} in repo #{repo[:name]}"
      )

      apply_build_status_from_pipeline(pipeline)
    end
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
  def apply_build_status_from_pipeline(pipeline)
    %w[INPROGRESS SUCCESSFUL FAILED].each do |state|
      @buildkite.builds_in_state(pipeline, state).each do |build|
        apply_build_state_for_build(build)
      end
    end
  rescue StandardError => e
    @log.exception(e)
  end

  # write the status of a build to bitbucket
  def apply_build_state_for_build(build)
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
    snitch_id = @config['dms']['snitch_id'].to_s
    Snitcher.snitch(snitch_id) if snitch_id != ''
  end
end
