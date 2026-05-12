# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  # RelationBackedQuerySpecification encapsulates all the options for building a SQL query
  # This separates the storage of query options from the actual query construction
  # and provides a cleaner interface for RelationBackedQuery
  class RelationBackedQuerySpecification
    # @rbs!
    #   @options: Hash[Symbol, untyped]
    attr_reader :options

    # @rbs options: Hash[Symbol, untyped]
    def initialize(options = {})
      @options = options
    end

    # Creates a new specification with merged options
    # @rbs new_options: Hash[Symbol, untyped] | RelationBackedQuerySpecification
    # @rbs return: Quo::RelationBackedQuerySpecification
    def merge(new_options)
      new_options = new_options.options if new_options.is_a?(self.class)
      self.class.new(options.merge(new_options))
    end

    # Apply all the specification options to the given ActiveRecord relation
    # @rbs relation: ActiveRecord::Relation
    # @rbs return: ActiveRecord::Relation
    def apply_to(relation)
      rel = relation
      rel = rel.select(*options[:select]) if options[:select]
      rel = rel.where(options[:where]) if options[:where]
      rel = rel.order(options[:order]) if options[:order]
      rel = rel.group(*options[:group]) if options[:group]
      rel = rel.limit(options[:limit]) if options[:limit]
      rel = rel.offset(options[:offset]) if options[:offset]
      if (joins = options[:joins])
        rel = joins.is_a?(Array) ? rel.joins(*joins) : rel.joins(joins)
      end
      if (left_outer_joins = options[:left_outer_joins])
        rel = left_outer_joins.is_a?(Array) ? rel.left_outer_joins(*left_outer_joins) : rel.left_outer_joins(left_outer_joins)
      end
      rel = rel.includes(*options[:includes]) if options[:includes]
      rel = rel.preload(*options[:preload]) if options[:preload]
      rel = rel.eager_load(*options[:eager_load]) if options[:eager_load]
      rel = rel.distinct if options[:distinct]
      rel = rel.reorder(options[:reorder]) if options[:reorder]
      rel = rel.extending(*options[:extending]) if options[:extending]
      rel = rel.unscope(options[:unscope]) if options[:unscope]
      rel
    end

    # Introspection

    # @rbs key: Symbol
    # @rbs return: bool
    def has?(key)
      options.key?(key)
    end

    # @rbs key: Symbol
    # @rbs return: untyped
    def [](key)
      options[key]
    end

    # Create helpers for each query option

    # @rbs *fields: untyped
    # @rbs return: Quo::RelationBackedQuerySpecification
    def select(*fields)
      merge(select: fields)
    end

    # @rbs conditions: untyped
    # @rbs return: Quo::RelationBackedQuerySpecification
    def where(conditions)
      merge(where: conditions)
    end

    # @rbs order_clause: untyped
    # @rbs return: Quo::RelationBackedQuerySpecification
    def order(order_clause)
      merge(order: order_clause)
    end

    # @rbs *columns: untyped
    # @rbs return: Quo::RelationBackedQuerySpecification
    def group(*columns)
      merge(group: columns)
    end

    # @rbs value: Integer
    # @rbs return: Quo::RelationBackedQuerySpecification
    def limit(value)
      merge(limit: value)
    end

    # @rbs value: Integer
    # @rbs return: Quo::RelationBackedQuerySpecification
    def offset(value)
      merge(offset: value)
    end

    # @rbs *tables: untyped
    # @rbs return: Quo::RelationBackedQuerySpecification
    def joins(*tables)
      merge(joins: tables)
    end

    # @rbs *tables: untyped
    # @rbs return: Quo::RelationBackedQuerySpecification
    def left_outer_joins(*tables)
      merge(left_outer_joins: tables)
    end

    # @rbs *associations: untyped
    # @rbs return: Quo::RelationBackedQuerySpecification
    def includes(*associations)
      merge(includes: associations)
    end

    # @rbs *associations: untyped
    # @rbs return: Quo::RelationBackedQuerySpecification
    def preload(*associations)
      merge(preload: associations)
    end

    # @rbs *associations: untyped
    # @rbs return: Quo::RelationBackedQuerySpecification
    def eager_load(*associations)
      merge(eager_load: associations)
    end

    # @rbs enabled: bool
    # @rbs return: Quo::RelationBackedQuerySpecification
    def distinct(enabled = true)
      merge(distinct: enabled)
    end

    # @rbs order_clause: untyped
    # @rbs return: Quo::RelationBackedQuerySpecification
    def reorder(order_clause)
      merge(reorder: order_clause)
    end

    # @rbs *modules: untyped
    # @rbs return: Quo::RelationBackedQuerySpecification
    def extending(*modules)
      merge(extending: modules)
    end

    # @rbs *args: untyped
    # @rbs return: Quo::RelationBackedQuerySpecification
    def unscope(*args)
      merge(unscope: args)
    end

    # Builds a new specification from a hash of options
    # @rbs options: Hash[Symbol, untyped]
    # @rbs return: Quo::RelationBackedQuerySpecification
    def self.build(options = {})
      new(options)
    end

    # Returns a blank specification
    # @rbs return: Quo::RelationBackedQuerySpecification
    def self.blank
      @blank ||= new
    end
  end
end
