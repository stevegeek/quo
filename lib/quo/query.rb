# frozen_string_literal: true

# rbs_inline: enabled

require "literal"

module Quo
  class Query < Literal::Struct
    include Literal::Types

    COERCE_TO_INT = ->(value) do #: (untyped value) -> Integer?
      return if value == Literal::Null
      value&.to_i
    end

    # @rbs!
    #   attr_accessor page (): Integer?
    #   attr_accessor page_size (): Integer?
    #   @current_page: Integer?
    prop :page, _Nilable(Integer), &COERCE_TO_INT
    prop(:page_size, _Nilable(Integer), default: -> { Quo.default_page_size || 20 }, &COERCE_TO_INT)


    def next_page_query #: Quo::Query
      copy(page: page + 1)
    end

    def previous_page_query #: Quo::Query
      copy(page: [page - 1, 1].max)
    end

    def offset #: Integer
      per_page = sanitised_page_size
      page_with_default = if page&.positive?
        page
      else
        1
      end
      per_page * (page_with_default - 1)
    end

    # Returns a active record query, or a Quo::Query instance
    def query #: Quo::Query | ::ActiveRecord::Relation
      raise NotImplementedError, "Query objects must define a 'query' method"
    end

    # @rbs **overrides: untyped
    # @rbs return: Quo::Query
    def copy(**overrides)
      self.class.new(**to_h.merge(overrides)).tap do |q|
        q.instance_variable_set(:@__transformer, transformer)
      end
    end

    # Compose is aliased as `+`. Can optionally take `joins` parameters to add joins on merged relation.
    # @rbs right: Quo::Query | ::ActiveRecord::Relation
    # @rbs joins: untyped
    # @rbs return: Quo::ComposedQuery
    def merge(right, joins: nil)
      ComposedQuery.merge_instances(self, right, joins: joins)
    end
    alias_method :+, :merge


    # @rbs @__transformer: nil | ^(untyped, ?Integer) -> untyped

    # Set a block used to transform data after query fetching
    # @rbs block: ^(untyped, ?Integer) -> untyped
    # @rbs return: self
    def transform(&block)
      @__transformer = block
      self
    end

    # Is this query object a ActiveRecord relation under the hood?
    def relation? #: bool
      test_relation(configured_query)
    end

    # Is this query object loaded data/collection under the hood? (ie not a AR relation)
    def collection? #: bool
      is_collection?(configured_query)
    end

    # Is this query object paged? (ie is paging enabled)
    def paged? #: bool
      page.present?
    end

    # Is this query object transforming results?
    def transform? #: bool
      transformer.present?
    end

    # Unwrap the paginated query
    def unwrap #: ActiveRecord::Relation
      configured_query
    end

    # Unwrap the un-paginated query
    def unwrap_unpaginated #: ActiveRecord::Relation
      underlying_query
    end


    private

    def transformer
      @__transformer
    end

    # The configured query is the underlying query with paging
    def configured_query #: void
      raise NotImplementedError, "Query objects must define a 'configured_query' method"
    end

    def sanitised_page_size #: Integer
      if page_size&.positive?
        given_size = page_size.to_i
        max_page_size = Quo.max_page_size || 200
        if given_size > max_page_size
          max_page_size
        else
          given_size
        end
      else
        Quo.default_page_size || 20
      end
    end

    # The underlying query is essentially the configured query with optional extras setup
    def underlying_query #: void
      raise NoMethodError, "Query objects must define a 'underlying_query' method"
    end

    # @rbs rel: untyped
    # @rbs return: bool
    def is_collection?(rel)
      rel.is_a?(Quo::CollectionBackedQuery) || (rel.is_a?(Enumerable) && !test_relation(rel))
    end

    # @rbs rel: untyped
    # @rbs return: bool
    def test_relation(rel)
      rel.is_a?(ActiveRecord::Relation)
    end
  end
end
