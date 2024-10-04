# frozen_string_literal: true

# rbs_inline: enabled

require "literal"

module Quo
  # @rbs inherits Quo::Query
  class RelationBackedQuery < Quo.base_query_class
    # @rbs query: ActiveRecord::Relation | Quo::Query
    # @rbs props: Hash[Symbol, untyped]
    # @rbs &block: () -> ActiveRecord::Relation | Quo::Query | Object & Enumerable[untyped]
    # @rbs return: Quo::RelationBackedQuery
    def self.wrap(query = nil, props: {}, &block)
      raise ArgumentError, "either a query or a block must be provided" unless query || block

      klass = Class.new(self) do
        props.each do |name, property|
          if property.is_a?(Literal::Property)
            prop name, property.type, property.kind, reader: property.reader, writer: property.writer, default: property.default
          else
            prop name, property
          end
        end
      end
      if block
        klass.define_method(:query, &block)
      else
        klass.define_method(:query) { query }
      end
      klass
    end

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

    # These store options related to building the underlying query, we don't want to expose these as public properties
    # @rbs!
    #   @_rel_group: untyped?
    #   @_rel_distinct: bool?
    #   @_rel_order: untyped?
    #   @_rel_limit: untyped?
    #   @_rel_preload: untyped?
    #   @_rel_includes: untyped?
    #   @_rel_select: untyped?
    prop :_rel_group, _Nilable(_Any), reader: false, writer: false
    prop :_rel_distinct, _Nilable(_Boolean), reader: false, writer: false
    prop :_rel_order, _Nilable(_Any), reader: false, writer: false
    prop :_rel_limit, _Nilable(_Any), reader: false, writer: false
    prop :_rel_preload, _Nilable(_Any), reader: false, writer: false
    prop :_rel_includes, _Nilable(_Any), reader: false, writer: false
    prop :_rel_select, _Nilable(_Any), reader: false, writer: false


    # Methods to prepare the query

    # SQL 'SELECT' configuration, calls to underlying AR relation
    # @rbs *options: untyped
    # @rbs return: Quo::Query
    def select(*options)
      copy(_rel_select: options)
    end

    # SQL 'LIMIT' configuration, calls to underlying AR relation
    # @rbs limit: untyped
    # @rbs return: Quo::Query
    def limit(limit)
      copy(_rel_limit: limit)
    end

    # SQL 'ORDER BY' configuration, calls to underlying AR relation
    # @rbs options: untyped
    # @rbs return: Quo::Query
    def order(options)
      copy(_rel_order: options)
    end

    # SQL 'GROUP BY' configuration, calls to underlying AR relation
    # @rbs *options: untyped
    # @rbs return: Quo::Query
    def group(*options)
      copy(_rel_group: options)
    end

    # Configures underlying AR relation to include associations
    # @rbs *options: untyped
    # @rbs return: Quo::Query
    def includes(*options)
      copy(_rel_includes: options)
    end

    # Configures underlying AR relation to preload associations
    # @rbs *options: untyped
    # @rbs return: Quo::Query
    def preload(*options)
      copy(_rel_preload: options)
    end

    # Calls to underlying AR distinct method
    # @rbs enabled: bool
    # @rbs return: Quo::Query
    def distinct(enabled = true)
      copy(_rel_distinct: enabled)
    end

    # Delegate methods that let us get the model class (available on AR relations)
    # @rbs def model: () -> (untyped | nil)
    # @rbs def klass: () -> (untyped | nil)
    delegate :model, :klass, to: :underlying_query

    # @rbs return: Quo::CollectionBackedQuery
    def to_collection(total_count: nil)
      Quo::CollectionBackedQuery.wrap(results.to_a).new(total_count:)
    end

    def results #: Quo::Results
      Quo::RelationResults.new(self, transformer: transformer)
    end

    # Return the SQL string for this query if its a relation type query object
    def to_sql #: String
      configured_query.to_sql if relation?
    end

    private

    def validated_query
      query.tap do |q|
        raise ArgumentError, "#query must return an ActiveRecord Relation or a Quo::Query instance" unless query.nil? || q.is_a?(::ActiveRecord::Relation) || q.is_a?(Quo::Query)
      end
    end

    # The underlying query is essentially the configured query with optional extras setup
    def underlying_query #: ActiveRecord::Relation
      rel = quo_unwrap_unpaginated_query(validated_query)

      rel = rel.group(@_rel_group) if @_rel_group.present?
      rel = rel.distinct if @_rel_distinct
      rel = rel.order(@_rel_order) if @_rel_order.present?
      rel = rel.limit(@_rel_limit) if @_rel_limit.present?
      rel = rel.preload(@_rel_preload) if @_rel_preload.present?
      rel = rel.includes(@_rel_includes) if @_rel_includes.present?
      @_rel_select.present? ? rel.select(@_rel_select) : rel
    end

    # The configured query is the underlying query with paging
    def configured_query #: ActiveRecord::Relation
      q = underlying_query
      return q unless paged?

      q.offset(offset).limit(sanitised_page_size)
    end
  end
end
