# frozen_string_literal: true

# rbs_inline: enabled

require_relative "quo/version"
require "quo/engine"

module Quo
  extend ActiveSupport::Autoload

  autoload :Query
  autoload :Results
  autoload :ComposedQuery
  autoload :EagerQuery
  autoload :LoadedQuery
  autoload :WrappedQuery

  mattr_accessor :base_query_class, default: "Quo::Query"
  mattr_accessor :max_page_size, default: 200
  mattr_accessor :default_page_size, default: 20

  def self.base_query_class #: Quo::Query
    @@base_query_class.constantize
  end
end
