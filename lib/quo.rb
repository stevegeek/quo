# frozen_string_literal: true

require_relative "quo/version"
require_relative "quo/railtie" if defined?(Rails)
require_relative "quo/query"
require_relative "quo/eager_query"
require_relative "quo/merged_query"
require_relative "quo/query_composer"
require_relative "quo/enumerator"

module Quo
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      configuration
    end
  end

  class Configuration
    attr_accessor :formatted_query_log, :query_show_callstack_size, :logger

    def initialize
      @formatted_query_log = true
      @query_show_callstack_size = 10
      @logger = nil
    end
  end
end
