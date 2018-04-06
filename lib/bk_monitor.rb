# frozen_string_literal: true

require 'mini_bucket'
require 'mini_kite'
require 'git_clone_url'

# Monitors buildkite and writes build status to bitbucket
class BkMonitor
  def initialize(config)
    @config = config
    @log = Logger.new(STDOUT)
    @bitbucket = MiniBucket.new(config['bitbucket'], log)
    @buildkite = MiniKite.new(config['buildkite'], log)
  end

  attr_writer :log

  attr_reader :log

  def start
    matched_pipelines.each_pair do |pipeline, repo|
      @log.info(
        "Processing builds for pipeline: #{pipeline} in repo #{repo[:name]}"
      )

      apply_build_status_from_pipeline(pipeline)
    end
  end

  private

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

  def apply_build_status_from_pipeline(pipeline)
    %w[INPROGRESS SUCCESSFUL FAILED].each do |state|
      @buildkite.builds_in_state(pipeline, state).each do |build|
        @log.info("Setting build state #{state} for #{build[:commit]}")
        @bitbucket.set_build_state_for_commit(build[:commit],
                                              state,
                                              build[:pipeline][:id],
                                              options_from_build(build))
      end
    end
  end

  def options_from_build(build)
    {
      name: "Buildkite build #{build[:number]}",
      url: build[:web_url],
      description: build[:message]
    }
  end
end
