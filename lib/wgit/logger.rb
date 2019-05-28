require 'logger'

module Wgit
  # The Logger instance used by Wgit. Set your own custom logger after
  # requiring this file if needed.
  @logger = nil

  # Returns the current Logger instance.
  # @return [Logger] The current Logger instance.
  def self.logger
    @logger
  end

  # Sets the current Logger instance.
  # @param logger [Logger] The Logger instance to use.
  # @return [Logger] The current Logger instance having being set.
  def self.logger=(logger)
    @logger = logger
  end

  # Returns the default Logger instance.
  # @return [Logger] The default Logger instance.
  def self.default_logger
    Logger.new(STDOUT, progname: 'wgit', level: :info)
  end

  # Sets the default Logger instance to be used by Wgit.
  # @return [Logger] The default Logger instance.
  def self.use_default_logger
    @logger = self.default_logger
  end
end