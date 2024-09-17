# frozen_string_literal: true

require_relative "quo/version"
require "quo/engine"

module Quo
  extend ActiveSupport::Autoload

  autoload :Callstack, "quo/utilities/callstack"
  autoload :Compose, "quo/utilities/compose"
  autoload :Sanitize, "quo/utilities/sanitize"
  autoload :Wrap, "quo/utilities/wrap"

  autoload :Query
  autoload :Results
  autoload :ComposedQuery
  autoload :EagerQuery
  autoload :LoadedQuery
  autoload :WrappedQuery

  mattr_accessor :base_query_class, default: "Quo::Query"
  mattr_accessor :formatted_query_log, default: true
  mattr_accessor :query_show_callstack_size, default: 10
  mattr_accessor :logger, default: nil
  mattr_accessor :max_page_size, default: 200
  mattr_accessor :default_page_size, default: 20

  def self.base_query_class
    @@base_query_class.constantize
  end
end
