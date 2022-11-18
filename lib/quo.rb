# frozen_string_literal: true

require_relative "quo/version"

module Quo
  class << self
    attr_reader :configuration

    def configure
      @configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end
  end

  # Configuration class for initializer
  class Configuration
    # @dynamic devise_password_hash
    attr_accessor :formatted_query_log, :query_show_callstack_size, :logger

    def initialize
      @formatted_query_log = true
      @query_show_callstack_size = 10
      @logger = nil
    end
  end
end
