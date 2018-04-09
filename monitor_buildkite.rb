#!/usr/bin/env ruby
# frozen_string_literal: true

DIR = File.expand_path('.', __dir__)
lib = File.join(DIR, 'lib')
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'bk_monitor'
require 'app_logger'
require 'app_settings'

log = AppLogger.new(STDOUT)

RestClient.log = log

config = AppSettings.load_settings

log.level = config['monitor']['log_level'] || 'WARN'

if config.valid?
  begin
    monitor = BkMonitor.new(config)
    monitor.log = log

    monitor.start
  rescue StandardError => e
    log.exception(e, true)
  end
else
  config.print_missing_settings_warning
  exit 1
end
