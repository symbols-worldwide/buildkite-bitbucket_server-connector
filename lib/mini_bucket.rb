# frozen_string_literal: true

require 'rest-client'
require 'cgi'
require 'json'

# REALLY minimal bitbucket API wrapper.
# Currently only supports the methods we use in this project.
class MiniBucket
  def initialize(options, log)
    @url = ENV['BITBUCKET_SERVER_URL'] || options['url']
    @user = ENV['BITBUCKET_SERVER_USERNAME'] || options['username']
    @pass = ENV['BITBUCKET_SERVER_PASSWORD'] || options['password']
    @log = log
  end

  def projects
    request(:get, 'projects', params: { limit: 100 })
  end

  def repositories(project)
    project_key = (project.is_a?(Hash) ? project[:key] : project).upcase
    request(:get, "projects/#{project_key}/repos")
  end

  def all_repos
    projects.map do |project|
      repositories(project)
    end.flatten
  end

  def set_build_state_for_commit(commit, state, key, options = {})
    request(:post,
            "commits/#{commit}",
            payload: {
              state: state,
              key: key
            }.merge(options).to_json,
            api: 'build-status')
  rescue StandardError => e
    @log.warn("Failed to write build status to Bitbucket for #{commit}. " +
      "Error: #{e}")
    @log.debug("State: #{state}, key: #{key}")
  end

  def build_state_for_commit(commit, key)
    build = request(:get,
                    "commits/#{commit}",
                    api: 'build-status').find { |b| b[:key] == key }
    build ? build[:state] : nil
  rescue StandardError => e
    @log.warn("Failed to get build status from Bitbucket. Error: #{e}")
  end

  private

  def request(method, url, options = {})
    resp = parse_response(
      RestClient::Request.execute(
        method: method,
        url: get_url(url, options[:params], options[:api] || 'api'),
        payload: options[:payload],
        headers: { 'Content-Type': 'application/json' }
      )
    )

    resp.include?(:isLastPage) ? unpage(resp, method, url, options) : resp
  end

  def get_url(url, params, api = 'api')
    u = URI.parse(@url)
    u.path = "#{u.path}/rest/#{api}/1.0/#{url}"
    u.user = @user
    u.password = @pass
    u.query = URI.encode_www_form(CGI.parse(u.query.to_s).merge(params || {}))
    u.to_s
  end

  def unpage(response, method, url, options)
    if !response[:isLastPage]
      options[:params] = paginate_params(response, options[:params])
      response[:values] + request(method, url, options)
    else
      response[:values]
    end
  end

  def paginate_params(response, payload)
    (payload || {}).merge(start: response[:nextPageStart])
  end

  def parse_response(response)
    JSON.parse(
      response.to_s == '' ? '{}' : response, symbolize_names: true
    )
  end
end
