# frozen_string_literal: true

# rbs_inline: enabled

require_relative "quo/version"
require "quo/engine"

module Quo
  extend ActiveSupport::Autoload

  autoload :Query
  autoload :Preloadable
  autoload :RelationBackedQuerySpecification
  autoload :RelationBackedQuery
  autoload :Results
  autoload :RelationResults
  autoload :CollectionResults
  autoload :ComposedQuery
  autoload :CollectionBackedQuery
  autoload :Composing

  mattr_accessor :relation_backed_query_base_class, default: "Quo::RelationBackedQuery"
  mattr_accessor :collection_backed_query_base_class, default: "Quo::CollectionBackedQuery"
  mattr_accessor :max_page_size, default: 200
  mattr_accessor :default_page_size, default: 20

  def self.relation_backed_query_base_class #: Quo::RelationBackedQuery
    @@relation_backed_query_base_class.constantize
  end

  def self.collection_backed_query_base_class #: Quo::CollectionBackedQuery
    @@collection_backed_query_base_class.constantize
  end
end
