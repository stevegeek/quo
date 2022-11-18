# frozen_string_literal: true

module Quo
  class Query
    # @deprecated - Query objects wont be Enumerable in future, they will implement part of Enumerable interface
    # but not all of it, some of which clashes with doing things right at DB level eg, sum. To use as an enumerable
    # use `to_a`
    include Enumerable

    class << self
      # Execute the query and return the first item
      def call(**options)
        new(**options).first
      end

      def call!(**options)
        new(**options).first!
      end

      # Combine two query-like or composeable entities:
      # These can be Quo::Query, Quo::MergedQuery, Quo::EagerQuery and ActiveRecord::Relations.
      # See the `README.md` docs for more details.
      def compose(query1, query2, joins = nil)
        Quo::QueryComposer.call(query1, query2, joins)
      end

      # Determines if the object `query` is something which can be composed with query objects
      def composable_with?(query)
        query.is_a?(Quo::Query) || query.is_a?(ActiveRecord::Relation)
      end

      # Wrap a relation in a Query. If the passed in object is already a query object then just return it
      def wrap(query_rel_or_data, **options)
        if query_rel_or_data.is_a?(Quo::Query) && options.present?
          return query_rel_or_data.copy(**options)
        end
        return query_rel_or_data if query_rel_or_data.is_a? Quo::Query
        if query_rel_or_data.is_a? ActiveRecord::Relation
          return new(**options.merge(scope: query_rel_or_data))
        end
        Quo::EagerQuery.new(**options.merge(collection: query_rel_or_data))
      end

      # ActiveRecord::Sanitization wrappers
      def sanitize_sql_for_conditions(conditions)
        ActiveRecord::Base.sanitize_sql_for_conditions(conditions)
      end

      def sanitize_sql_string(string)
        sanitize_sql_for_conditions(["'%s'", string])
      end

      def sanitize_sql_parameter(value)
        sanitize_sql_for_conditions(["?", value])
      end

      # 'trim' a query, ie remove comments and remove newlines
      # This will remove dashes from inside strings too
      def trim_query(sql)
        sql.gsub(/--[^\n'"]*\n/m, " ").tr("\n", " ").strip
      end

      def formatted_queries?
        !!Quo.configuration.formatted_query_log
      end
    end

    attr_reader :current_page, :page_size, :options

    def initialize(**options)
      @options = options
      @current_page = options[:page]&.to_i || options[:current_page]&.to_i
      @page_size = options[:page_size]&.to_i || 20
      @scope = unwrap_relation(options[:scope])
    end

    # Returns a active record query, or a Quo::Query instance
    # You must provide an implementation of this of pass the 'scope' option on instantiation
    def query
      return @scope unless @scope.nil?
      raise NotImplementedError, "Query objects must define a 'query' method"
    end

    # Combine (compose) this query object with another composeable entity, see notes for `.compose` above.
    # Compose is aliased as `+`. Can optionally take `joins()` parameters to perform a joins before the merge
    def compose(right, joins = nil)
      Quo::QueryComposer.call(self, right, joins)
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

    # @deprecated - Query objects should not change the query, only order etc
    def left_outer_joins(*options)
      copy(left_outer_joins: options)
    end

    # http://www.chrisrolle.com/en/blog/benchmark-preload-vs-eager_load
    def preload(*options)
      copy(preload: options)
    end

    # @deprecated - Query objects should not change the query, only order etc
    def joins(*options)
      copy(joins: options)
    end

    def unscope(*options)
      copy(unscope: options)
    end

    # Prefix 'sql' to avoid conflict with enumerable method
    def sql_select(*options)
      copy(select: options)
    end

    # The following methods actually execute the underlying query

    # Gets the actual count of elements in the page of results (assuming paging is being used, otherwise the count of
    # all results)
    def page_count
      query_with_logging.count
    end

    # Delegate SQL calculation methods to the underlying query
    delegate :sum, :average, :minimum, :maximum, to: :query_with_logging

    # Gets the count of all results ignoring the current page and page size (if set)
    delegate :count, to: :underlying_query
    alias_method :total_count, :count
    alias_method :size, :count

    # Delegate methods that let us get the model class (available on AR relations)
    delegate :model, :klass, to: :underlying_query

    # Get first elements
    def first(*args)
      if transform?
        res = query_with_logging.first(*args)
        if res.is_a? Array
          res.map.with_index { |r, i| transformer.call(r, i) }
        elsif !res.nil?
          transformer.call(query_with_logging.first(*args))
        end
      else
        query_with_logging.first(*args)
      end
    end

    def first!(*args)
      item = first(*args)
      raise ActiveRecord::RecordNotFound, "No item could be found!" unless item
      item
    end

    # Get last elements
    def last(*args)
      if transform?
        res = query_with_logging.last(*args)
        if res.is_a? Array
          res.map.with_index { |r, i| transformer.call(r, i) }
        elsif !res.nil?
          transformer.call(query_with_logging.last(*args))
        end
      else
        query_with_logging.last(*args)
      end
    end

    # Convert to array
    def to_a
      arr = query_with_logging.to_a
      transform? ? arr.map.with_index { |r, i| transformer.call(r, i) } : arr
    end

    # Convert to EagerQuery
    def to_eager(more_opts = {})
      Quo::EagerQuery.new(collection: to_a, **options.merge(more_opts))
    end

    # Iterate over each result of query with block
    def each
      query_with_logging.each_with_index do |item, i|
        yield(transform? ? transformer.call(item, i) : item)
      end
    end

    # TODO: We should review if we really want to expose all this
    # `q_` Enumerable methods return eager query objects instead of Array
    %i[
      q_collect
      q_map
      q_flat_map
      q_collect_concat
      q_drop
      q_drop_while
      q_filter
      q_select
      q_find_all
      q_grep
      q_grep_v
      q_reject
      q_sort
      q_sort_by
      q_take_while
      q_take
    ].each do |name|
      define_method(name) do |*args, &block|
        result = send(name.to_s[2..].to_sym, *args, &block)
        self.class.wrap(result, page: current_page, page_size: page_size, total_count: total_count)
      end
    end

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

    protected

    def formatted_queries?
      self.class.formatted_queries?
    end

    def format_query(sql_str)
      formatted_queries? ? sql_str : ::Quo::Query.trim_query(sql_str)
    end

    def transformer
      options[:__transformer]
    end

    def offset
      per_page = sanitised_page_size
      page = current_page.positive? ? current_page : 1
      per_page * (page - 1)
    end

    # The configured query is the underlying query with paging
    def configured_query
      q = underlying_query
      return q unless paged? && q.is_a?(ActiveRecord::Relation)
      q.offset(offset).limit(sanitised_page_size)
    end

    def sanitised_page_size
      page_size.present? && page_size.positive? ? [page_size.to_i, 200].min : 20
    end

    # TODO: we could also expose a method to do value based paging, ie you provide the
    # current sort column, and last value, and then do 'where column > last_value'
    # This couples well with infinite scrolling but means you cant go to a specific page

    # The underlying query is essentially the configured query with optional extras setup
    def underlying_query
      @underlying_query ||=
        begin
          rel = unwrap_relation(query)
          unless test_eager(rel)
            rel = rel.unscope(@options[:unscope]) if @options[:unscope].present?
            rel = rel.group(@options[:group]) if @options[:group].present?
            rel = rel.order(@options[:order]) if @options[:order].present?
            rel = rel.limit(@options[:limit]) if @options[:limit].present?
            rel = rel.preload(@options[:preload]) if @options[:preload].present?
            rel = rel.includes(@options[:includes]) if @options[:includes].present?
            rel = rel.joins(@options[:joins]) if @options[:joins].present?
            rel = rel.eager_load(@options[:left_outer_joins]) if @options[:left_outer_joins]
              .present?
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

    def query_with_logging
      debug_callstack if Rails.env.development?
      configured_query
    end

    def debug_callstack
      return unless Quo.configuration.query_show_callstack_size&.positive?
      max_stack = Quo.configuration.query_show_callstack_size
      working_dir = Dir.pwd
      exclude = %r{/(gems/|rubies/|query\.rb)}
      stack = Kernel.caller.grep_v(exclude).map { |l| l.gsub(working_dir + "/", "") }
      trace_message = stack[0..max_stack].join("\n               &> ")
      message = "\n[Query stack]: -> #{trace_message}\n"
      message += " (truncated to #{max_stack} most recent)" if stack.size > max_stack
      Quo.configuration.logger&.info(message)
    end
  end
end
