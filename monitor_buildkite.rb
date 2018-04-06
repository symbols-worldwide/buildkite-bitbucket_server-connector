#!/usr/bin/env ruby
# frozen_string_literal: true

DIR = File.expand_path('.', __dir__)
lib = File.join(DIR, 'lib')
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'yaml'
require 'bk_monitor'
require 'app_logger'
require 'erb'

log = AppLogger.new(STDOUT)

RestClient.log = log

erb = ERB.new(File.read('config.yml'))
config = YAML.safe_load(erb.result)

log.level = config['log_level'] || 'DEBUG'

begin
  monitor = BkMonitor.new(config)
  monitor.log = log
  monitor.start
rescue StandardError => e
  log.exception(e, true)
end
