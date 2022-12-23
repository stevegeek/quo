# frozen_string_literal: true

require_relative "./utilities/callstack"
require_relative "./utilities/compose"
require_relative "./utilities/sanitize"
require_relative "./utilities/wrap"

module Quo
  class Query
    include Quo::Utilities::Callstack

    extend Quo::Utilities::Compose
    extend Quo::Utilities::Sanitize
    extend Quo::Utilities::Wrap

    class << self
      def call(**options)
        new(**options).first
      end

      def call!(**options)
        new(**options).first!
      end
    end

    attr_reader :current_page, :page_size, :options

    def initialize(**options)
      @options = options
      @current_page = options[:page]&.to_i || options[:current_page]&.to_i
      @page_size = options[:page_size]&.to_i || Quo.configuration.default_page_size || 20
    end

    # Returns a active record query, or a Quo::Query instance
    def query
      raise NotImplementedError, "Query objects must define a 'query' method"
    end

    # Combine (compose) this query object with another composeable entity, see notes for `.compose` above.
    # Compose is aliased as `+`. Can optionally take `joins()` parameters to perform a joins before the merge
    def compose(right, joins: nil)
      Quo::QueryComposer.new(self, right, joins).compose
    end

    alias_method :+, :compose

    def copy(**options)
      self.class.new(**@options.merge(options))
    end

    # Methods to prepare the query
    def limit(limit)
      copy(limit: limit)
    end

    def order(options)
      copy(order: options)
    end

    def group(*options)
      copy(group: options)
    end

    def includes(*options)
      copy(includes: options)
    end

    def preload(*options)
      copy(preload: options)
    end

    def select(*options)
      copy(select: options)
    end

    # The following methods actually execute the underlying query

    # Delegate SQL calculation methods to the underlying query
    delegate :sum, :average, :minimum, :maximum, to: :query_with_logging

    # Gets the count of all results ignoring the current page and page size (if set)
    delegate :count, to: :underlying_query
    alias_method :total_count, :count
    alias_method :size, :count

    # Gets the actual count of elements in the page of results (assuming paging is being used, otherwise the count of
    # all results)
    def page_count
      query_with_logging.count
    end

    # Delegate methods that let us get the model class (available on AR relations)
    delegate :model, :klass, to: :underlying_query

    # Get first elements
    def first(limit = nil)
      if transform?
        res = query_with_logging.first(limit)
        if res.is_a? Array
          res.map.with_index { |r, i| transformer.call(r, i) }
        elsif !res.nil?
          transformer.call(query_with_logging.first(*args))
        end
      else
        query_with_logging.first(limit)
      end
    end

    def first!(limit = nil)
      item = first(limit)
      raise ActiveRecord::RecordNotFound, "No item could be found!" unless item
      item
    end

    # Get last elements
    def last(limit = nil)
      if transform?
        res = query_with_logging.last(limit)
        if res.is_a? Array
          res.map.with_index { |r, i| transformer.call(r, i) }
        elsif !res.nil?
          transformer.call(query_with_logging.last(*args))
        end
      else
        query_with_logging.last(limit)
      end
    end

    # Convert to array
    def to_a
      arr = query_with_logging.to_a
      transform? ? arr.map.with_index { |r, i| transformer.call(r, i) } : arr
    end

    # Convert to EagerQuery, and load all data
    def to_eager(more_opts = {})
      Quo::EagerQuery.new(to_a, **options.merge(more_opts))
    end
    alias_method :load, :to_eager

    def results
      Quo::Results.new(self, transformer: transformer)
    end

    # Some convenience methods for working with results
    delegate :each,
      :map,
      :flat_map,
      :reduce,
      :reject,
      :filter,
      :find,
      :include?,
      :each_with_object,
      to: :results

    # Set a block used to transform data after query fetching
    def transform(&block)
      @options[:__transformer] = block
      self
    end

    # Are there any results for this query?
    def exists?
      return query_with_logging.exists? if relation?
      query_with_logging.present?
    end

    # Are there no results for this query?
    def none?
      !exists?
    end
    alias_method :empty?, :none?

    # Is this query object a relation under the hood? (ie not eager loaded)
    def relation?
      test_relation(configured_query)
    end

    # Is this query object eager loaded data under the hood? (ie not a relation)
    def eager?
      test_eager(configured_query)
    end

    # Is this query object paged? (ie is paging enabled)
    def paged?
      current_page.present?
    end

    # Is this query object transforming results?
    def transform?
      transformer.present?
    end

    # Return the SQL string for this query if its a relation type query object
    def to_sql
      configured_query.to_sql if relation?
    end

    # Unwrap the underlying query
    def unwrap
      configured_query
    end

    delegate :distinct, to: :configured_query

    private

    def formatted_queries?
      !!Quo.configuration.formatted_query_log
    end

    # 'trim' a query, ie remove comments and remove newlines
    # This will remove dashes from inside strings too
    def trim_query(sql)
      sql.gsub(/--[^\n'"]*\n/m, " ").tr("\n", " ").strip
    end

    def format_query(sql_str)
      formatted_queries? ? sql_str : trim_query(sql_str)
    end

    def transformer
      options[:__transformer]
    end

    def offset
      per_page = sanitised_page_size
      page = current_page&.positive? ? current_page : 1
      per_page * (page - 1)
    end

    # The configured query is the underlying query with paging
    def configured_query
      q = underlying_query
      return q unless paged? && q.is_a?(ActiveRecord::Relation)
      q.offset(offset).limit(sanitised_page_size)
    end

    def sanitised_page_size
      if page_size && page_size.positive?
        given_size = page_size.to_i
        max_page_size = Quo.configuration.max_page_size || 200
        if given_size > max_page_size
          max_page_size
        else
          given_size
        end
      else
        Quo.configuration.default_page_size || 20
      end
    end

    def query_with_logging
      debug_callstack
      configured_query
    end

    # The underlying query is essentially the configured query with optional extras setup
    def underlying_query
      @underlying_query ||=
        begin
          rel = unwrap_relation(query)
          unless test_eager(rel)
            rel = rel.group(@options[:group]) if @options[:group].present?
            rel = rel.order(@options[:order]) if @options[:order].present?
            rel = rel.limit(@options[:limit]) if @options[:limit].present?
            rel = rel.preload(@options[:preload]) if @options[:preload].present?
            rel = rel.includes(@options[:includes]) if @options[:includes].present?
            rel = rel.select(@options[:select]) if @options[:select].present?
          end
          rel
        end
    end

    def unwrap_relation(query)
      query.is_a?(Quo::Query) ? query.unwrap : query
    end

    def test_eager(rel)
      rel.is_a?(Enumerable) && !test_relation(rel)
    end

    def test_relation(rel)
      rel.is_a?(ActiveRecord::Relation)
    end
  end
end
