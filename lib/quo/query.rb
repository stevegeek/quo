# frozen_string_literal: true

# rbs_inline: enabled

require "literal"

module Quo
  class Query < Literal::Struct
    include Literal::Types

    # @rbs conditions: untyped?
    # @rbs return: String
    def self.sanitize_sql_for_conditions(conditions)
      ActiveRecord::Base.sanitize_sql_for_conditions(conditions)
    end

    # @rbs string: String
    # @rbs return: String
    def self.sanitize_sql_string(string)
      sanitize_sql_for_conditions(["'%s'", string])
    end

    # @rbs value: untyped
    # @rbs return: String
    def self.sanitize_sql_parameter(value)
      sanitize_sql_for_conditions(["?", value])
    end

    # 'Smart' wrap Query, ActiveRecord::Relation or a data collection in a Query.
    # Calls out to Quo::WrappedQuery.wrap or Quo::CollectionBackedQuery.wrap as appropriate.
    def self.wrap(query_rel_or_data, **options)
      if query_rel_or_data < Quo::Query
        query_rel_or_data
      elsif query_rel_or_data.is_a?(ActiveRecord::Relation)
        Quo::WrappedQuery.wrap(query_rel_or_data, **options)
      else
        Quo::CollectionBackedQuery.wrap(query_rel_or_data)
      end
    end

    def self.wrap_instance(query_rel_or_data)
      if query_rel_or_data.is_a?(Quo::Query)
        query_rel_or_data
      elsif query_rel_or_data.is_a?(ActiveRecord::Relation)
        Quo::WrappedQuery.wrap(query_rel_or_data).new
      else
        Quo::CollectionBackedQuery.wrap(query_rel_or_data).new
      end
    end

    # @rbs query: untyped
    # @rbs return: bool
    def self.composable_with?(query)
      query.is_a?(Quo::Query) || query.is_a?(ActiveRecord::Relation)
    end

    # Compose is aliased as `+`. Can optionally take `joins` parameters to add joins on merged relation.
    # @rbs right: Quo::Query | ActiveRecord::Relation | Object & Enumerable[untyped]
    # @rbs joins: Symbol | Hash[Symbol, untyped] | Array[Symbol | Hash[Symbol, untyped]]
    def self.compose(right, joins: nil)
      ComposedQuery.composer(self, right, joins: joins)
    end
    singleton_class.alias_method :+, :compose

    # @rbs ovveride
    def self.prop(name, type, kind = :keyword, reader: :public, writer: :public, default: nil, shadow_check: true)
      if shadow_check && reader && instance_methods.include?(name.to_sym)
        raise ArgumentError, "Property name '#{name}' shadows an existing method"
      end
      if shadow_check && writer && instance_methods.include?(:"#{name}=")
        raise ArgumentError, "Property name '#{name}' shadows an existing writer method '#{name}='"
      end
      super(name, type, kind, reader: reader, writer: writer, default: default)
    end

    # @rbs **options: untyped
    # @rbs return: untyped
    def self.call(**options)
      new(**options).first
    end

    # @rbs **options: untyped
    # @rbs return: untyped
    def self.call!(**options)
      new(**options).first!
    end

    COERCE_TO_INT = ->(value) do #: (untyped value) -> Integer?
      return if value == Literal::Null
      value&.to_i
    end

    # @rbs!
    #   attr_accessor page (): Integer?
    #   attr_accessor current_page (): Integer?
    #   attr_accessor page_size (): Integer?

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

    def page_index #: Integer
      page || current_page
    end

    def next_page_query #: Quo::Query
      copy(page: page_index + 1)
    end

    def previous_page_query #: Quo::Query
      copy(page: [page_index - 1, 1].max)
    end

    # @deprecated - to be removed!!
    def options #: Hash[Symbol, untyped]
      @options ||= to_h.dup
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

    # Methods to prepare the query
    # @rbs limit: untyped
    # @rbs return: Quo::Query
    def limit(limit)
      copy(limit: limit)
    end

    # @rbs options: untyped
    # @rbs return: Quo::Query
    def order(options)
      copy(order: options)
    end

    # @rbs *options: untyped
    # @rbs return: Quo::Query
    def group(*options)
      copy(group: options)
    end

    # @rbs *options: untyped
    # @rbs return: Quo::Query
    def includes(*options)
      copy(includes: options)
    end

    # @rbs *options: untyped
    # @rbs return: Quo::Query
    def preload(*options)
      copy(preload: options)
    end

    # @rbs *options: untyped
    # @rbs return: Quo::Query
    def select(*options)
      copy(select: options)
    end

    # The following methods actually execute the underlying query

    # Delegate SQL calculation methods to the underlying query
    # @rbs def sum: (?untyped column_name) -> Numeric
    # @rbs def average: (untyped column_name) -> Numeric
    # @rbs def minimum: (untyped column_name) -> Numeric
    # @rbs def maximum: (untyped column_name) -> Numeric
    delegate :sum, :average, :minimum, :maximum, to: :configured_query

    # Gets the count of all results ignoring the current page and page size (if set).
    def count #: Integer
      count_query(underlying_query)
    end

    alias_method :total_count, :count
    alias_method :size, :count

    # Gets the actual count of elements in the page of results (assuming paging is being used, otherwise the count of
    # all results)
    def page_count #: Integer
      count_query(configured_query)
    end

    # Delegate methods that let us get the model class (available on AR relations)
    # @rbs def model: () -> (untyped | nil)
    # @rbs def klass: () -> (untyped | nil)
    delegate :model, :klass, to: :underlying_query

    # Get first elements
    # @rbs limit: ?Integer
    # @rbs return: untyped
    def first(limit = nil)
      if transform?
        res = configured_query.first(limit)
        if res.is_a? Array
          res.map.with_index { |r, i| transformer&.call(r, i) }
        elsif !res.nil?
          transformer&.call(configured_query.first(limit))
        end
      elsif limit
        configured_query.first(limit)
      else
        # Array#first will not take nil as a limit
        configured_query.first
      end
    end

    # Get first elements or raise an error if none are found
    # @rbs limit: ?Integer
    # @rbs return: untyped
    def first!(limit = nil)
      item = first(limit)
      raise ActiveRecord::RecordNotFound, "No item could be found!" unless item
      item
    end

    # Get last elements
    # @rbs limit: ?Integer
    # @rbs return: untyped
    def last(limit = nil)
      if transform?
        res = configured_query.last(limit)
        if res.is_a? Array
          res.map.with_index { |r, i| transformer&.call(r, i) }
        elsif !res.nil?
          transformer&.call(res)
        end
      elsif limit
        configured_query.last(limit)
      else
        configured_query.last
      end
    end

    # Convert to array
    # @rbs return: Array[untyped]
    def to_a
      arr = configured_query.to_a
      transform? ? arr.map.with_index { |r, i| transformer&.call(r, i) } : arr
    end

    # @rbs return: Quo::CollectionBackedQuery
    def to_eager
      Quo::CollectionBackedQuery.wrap(to_a).new
    end
    alias_method :load, :to_eager

    def results #: Quo::Results
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

    # @rbs @__transformer: nil | ^(untyped, ?Integer) -> untyped

    # Set a block used to transform data after query fetching
    # @rbs block: ^(untyped, ?Integer) -> untyped
    # @rbs return: self
    def transform(&block)
      @__transformer = block
      self
    end

    # Are there any results for this query?
    def exists? #: bool
      return configured_query.exists? if relation?
      configured_query.present?
    end

    # Are there no results for this query?
    def none? #: bool
      !exists?
    end
    alias_method :empty?, :none?

    # Is this query object a relation under the hood? (ie not eager loaded)
    def relation? #: bool
      test_relation(configured_query)
    end

    # Is this query object eager loaded data under the hood? (ie not a relation)
    def eager? #: bool
      test_eager(configured_query)
    end

    # Is this query object paged? (ie is paging enabled)
    def paged? #: bool
      page_index.present?
    end

    # Is this query object transforming results?
    def transform? #: bool
      transformer.present?
    end

    # Return the SQL string for this query if its a relation type query object
    def to_sql #: String
      configured_query.to_sql if relation?
    end

    # Unwrap the paginated query
    def unwrap #: ActiveRecord::Relation
      configured_query
    end

    # Unwrap the un-paginated query
    def unwrap_unpaginated #: ActiveRecord::Relation
      underlying_query
    end

    # @rbs! def distinct: () -> ActiveRecord::Relation
    delegate :distinct, to: :configured_query

    private

    def transformer
      @__transformer
    end

    def offset #: Integer
      per_page = sanitised_page_size
      page = if page_index&.positive?
        page_index
      else
        1
      end
      per_page * (page - 1)
    end

    # The configured query is the underlying query with paging
    def configured_query #: ActiveRecord::Relation
      q = underlying_query
      return q unless paged? && q.is_a?(ActiveRecord::Relation)
      q.offset(offset).limit(sanitised_page_size)
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
    def underlying_query #: ActiveRecord::Relation
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

    # @rbs query: Quo::Query | ::ActiveRecord::Relation
    # @rbs return: ActiveRecord::Relation
    def unwrap_relation(query)
      query.is_a?(Quo::Query) ? query.unwrap : query
    end

    # @rbs rel: untyped
    # @rbs return: bool
    def test_eager(rel)
      rel.is_a?(Quo::CollectionBackedQuery) || (rel.is_a?(Enumerable) && !test_relation(rel))
    end

    # @rbs rel: untyped
    # @rbs return: bool
    def test_relation(rel)
      rel.is_a?(ActiveRecord::Relation)
    end

    # Note we reselect the query as this prevents query errors if the SELECT clause is not compatible with COUNT
    # (SQLException: wrong number of arguments to function COUNT()). We do this in two ways, either with the primary key
    # or with Arel.star. The primary key is the most compatible way to count, but if the query does not have a primary
    # we fallback. The fallback "*" wont work in certain situations though, specifically if we have a limit() on the query
    # which Arel constructs as a subquery. In this case we will get a SQL error as the generated SQL contains
    # `SELECT COUNT(count_column) FROM (SELECT * AS count_column FROM ...) subquery_for_count` where the error is:
    # `ActiveRecord::StatementInvalid: SQLite3::SQLException: near "AS": syntax error`
    # Either way DB engines know how to count efficiently.
    # @rbs query: ActiveRecord::Relation
    # @rbs return: Integer
    def count_query(query)
      pk = query.model.primary_key
      if pk
        query.reselect(pk).count
      else
        query.reselect(Arel.star).count
      end
    end
  end
end
