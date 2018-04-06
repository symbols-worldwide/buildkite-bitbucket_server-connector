# frozen_string_literal: true

require 'yaml'
require 'erb'

# Extension of Hash to validate app settings
module AppSettings
  def valid?
    required_settings.all? { |setting| setting? setting }
  end

  def print_missing_settings_warning
    warn <<~WARNING
      Some settings are not set. Please set the following settings via config.yml
      or environment variables.
    WARNING

    warn required_settings.reject { |s| setting? s }
                          .map { |s| " * #{setting_to_env(s)}" }
                          .join("\n")
  end

  def self.load_settings
    config = YAML.safe_load(ERB.new(File.read('config.yml')).result)
    config.extend(AppSettings)
    config
  end

  private

  def required_settings
    [
      %w[buildkite polling_interval],
      %w[buildkite update_window],
      %w[buildkite token],
      %w[buildkite organization],
      %w[bitbucket username],
      %w[bitbucket password],
      %w[bitbucket url]
    ]
  end

  def setting?(setting)
    c = self
    setting.each { |key| c ? c = c[key] : c }
    c.to_s != ''
  end

  def setting_to_env(setting)
    setting.map(&:upcase).join('_')
  end
end
