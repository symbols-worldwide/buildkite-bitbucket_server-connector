# frozen_string_literal: true

require 'colorize'

# A formatter that writes in color
class AppFormatter < Logger::Formatter
  def call(severity, datetime, progname, msg)
    message = super(severity, datetime, progname, msg)
    message.colorize(AppFormatter.color_for(severity))
  end

  def self.color_for(severity)
    {
      DEBUG: :light_black,
      FATAL: :light_red,
      ERROR: :red,
      WARN: :yellow
    }[severity.to_sym] || :default
  end
end

# Uses the colorized formatter and overrides << for rest-client
class AppLogger < Logger
  def <<(msg)
    debug(msg.strip)
  end

  def initialize(device)
    super(device)
    self.formatter = AppFormatter.new
  end

  def exception(exception, is_fatal = false)
    if is_fatal
      fatal exception_string(exception)
      error backtrace_string(exception)
    else
      error exception_string(exception)
    end
  end

  private

  def exception_string(exception)
    "#{exception.backtrace.first}: #{exception.message} (#{exception.class})"
  end

  def backtrace_string(exception)
    exception.backtrace.drop(1).map { |m| "\n -  #{m}" }.join('')
  end
end
