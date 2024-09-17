# frozen_string_literal: true

require_relative "utilities/callstack"
require_relative "utilities/compose"
require_relative "utilities/sanitize"
require_relative "utilities/wrap"

require "literal"

module Quo
  class Query < Literal::Struct
    include Literal::Types
    include Quo::Utilities::Callstack
    include Quo::Utilities::Compose
    extend Quo::Utilities::Sanitize
    extend Quo::Utilities::Wrap

    class << self
      def prop(name, type, kind = :keyword, reader: :public, writer: :public, default: nil, shadow_check: true)
        if shadow_check && reader && instance_methods.include?(name.to_sym)
          raise ArgumentError, "Property name '#{name}' shadows an existing method"
        end
        if shadow_check && writer && instance_methods.include?(:"#{name}=")
          raise ArgumentError, "Property name '#{name}' shadows an existing writer method '#{name}='"
        end
        super(name, type, kind, reader: reader, writer: writer, default: default)
      end

      def call(**options)
        new(**options).first
      end

      def call!(**options)
        new(**options).first!
      end
    end

    COERCE_TO_INT = ->(value) do
      return if value == Literal::Null
      value&.to_i
    end

    prop :page, _Nilable(Integer), &COERCE_TO_INT
    prop :current_page, _Nilable(Integer), &COERCE_TO_INT
    prop(:page_size, _Nilable(Integer), default: -> { Quo.default_page_size || 20 }, &COERCE_TO_INT)

    # TODO: maybe deprecate these, they are set using the chainable method and when merging we can handle them separately?
    prop :group, _Nilable(_Any), reader: false, writer: false
    prop :order, _Nilable(_Any), reader: false, writer: false
    prop :limit, _Nilable(_Any), reader: false, writer: false
    prop :preload, _Nilable(_Any), reader: false, writer: false
    prop :includes, _Nilable(_Any), reader: false, writer: false
    prop :select, _Nilable(_Any), reader: false, writer: false

    # def after_initialization
    #   @current_page = options[:page]&.to_i || options[:current_page]&.to_i
    #   @page_size = options[:page_size]&.to_i || Quo.default_page_size || 20
    # end

    def page_index
      page || current_page
    end

    # @deprecated - to be removed!!
    def options
      @options ||= to_h.dup
    end

    # Returns a active record query, or a Quo::Query instance
    def query
      raise NotImplementedError, "Query objects must define a 'query' method"
    end

    def copy(**overrides)
      self.class.new(**to_h.merge(overrides)).tap do |q|
        q.instance_variable_set(:@__transformer, transformer)
      end
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
          res.map.with_index { |r, i| transformer&.call(r, i) }
        elsif !res.nil?
          transformer&.call(query_with_logging.first(limit))
        end
      elsif limit
        query_with_logging.first(limit)
      else
        # Array#first will not take nil as a limit
        query_with_logging.first
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
          res.map.with_index { |r, i| transformer&.call(r, i) }
        elsif !res.nil?
          transformer&.call(res)
        end
      elsif limit
        query_with_logging.last(limit)
      else
        query_with_logging.last
      end
    end

    # Convert to array
    def to_a
      arr = query_with_logging.to_a
      transform? ? arr.map.with_index { |r, i| transformer&.call(r, i) } : arr
    end

    def to_eager
      Quo::LoadedQuery.wrap(to_a).new
    end
    alias_method :load, :to_eager

    def results
      Quo::Results.new(self, transformer: transformer)
    end

    # Some convenience methods for working with results
    delegate :each,
      :find_each,
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
      @__transformer = block
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
      page_index.present?
    end

    # Is this query object transforming results?
    def transform?
      transformer.present?
    end

    # Return the SQL string for this query if its a relation type query object
    def to_sql
      configured_query.to_sql if relation?
    end

    # Unwrap the paginated query
    def unwrap
      configured_query
    end

    # Unwrap the un-paginated query
    def unwrap_unpaginated
      underlying_query
    end

    delegate :distinct, to: :configured_query

    private

    def formatted_queries?
      !!Quo.formatted_query_log
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
      @__transformer
    end

    def offset
      per_page = sanitised_page_size
      page = if page_index&.positive?
        page_index
      else
        1
      end
      per_page * (page - 1)
    end

    # The configured query is the underlying query with paging
    def configured_query
      q = underlying_query
      return q unless paged? && q.is_a?(ActiveRecord::Relation)
      q.offset(offset).limit(sanitised_page_size)
    end

    def sanitised_page_size
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
            rel = rel.group(options[:group]) if options[:group].present?
            rel = rel.order(options[:order]) if options[:order].present?
            rel = rel.limit(options[:limit]) if options[:limit].present?
            rel = rel.preload(options[:preload]) if options[:preload].present?
            rel = rel.includes(options[:includes]) if options[:includes].present?
            rel = rel.select(options[:select]) if options[:select].present?
          end
          rel
        end
    end

    def unwrap_relation(query)
      query.is_a?(Quo::Query) ? query.unwrap : query
    end

    def test_eager(rel)
      rel.is_a?(Quo::LoadedQuery) || (rel.is_a?(Enumerable) && !test_relation(rel))
    end

    def test_relation(rel)
      rel.is_a?(ActiveRecord::Relation)
    end
  end
end
