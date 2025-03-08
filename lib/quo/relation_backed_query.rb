# frozen_string_literal: true

# rbs_inline: enabled

require "literal"

module Quo
  class RelationBackedQuery < Query
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

    # The query specification stores all options related to building the query
    # @rbs!
    #   @_specification: Quo::QuerySpecification?
    prop :_specification, _Nilable(Quo::QuerySpecification), 
         default: -> { QuerySpecification.blank }, 
         reader: false, 
         writer: false

    # Apply a query specification to this query
    # @rbs specification: Quo::QuerySpecification
    # @rbs return: Quo::Query
    def with_specification(specification)
      copy(_specification: specification)
    end

    # Apply query options using the specification
    # @rbs options: Hash[Symbol, untyped]
    # @rbs return: Quo::Query 
    def with(options = {})
      spec = @_specification || QuerySpecification.blank
      with_specification(spec.merge(options))
    end

    # Delegate methods that let us get the model class (available on AR relations)
    # @rbs def model: () -> (untyped | nil)
    # @rbs def klass: () -> (untyped | nil)
    delegate :model, :klass, to: :underlying_query

    # @rbs return: Quo::CollectionBackedQuery
    def to_collection(total_count: nil)
      Quo.collection_backed_query_base_class.wrap(results.to_a).new(total_count:)
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
      
      # Apply specification if it exists
      if @_specification
        @_specification.apply_to(rel)
      else
        rel
      end
    end

    # The configured query is the underlying query with paging
    def configured_query #: ActiveRecord::Relation
      q = underlying_query
      return q unless paged?

      q.offset(offset).limit(sanitised_page_size)
    end
  end
end
