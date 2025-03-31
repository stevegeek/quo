# frozen_string_literal: true

# rbs_inline: enabled

require_relative "base_strategy"

module Quo
  module Composing
    # Base class for class composition strategies
    class ClassStrategy < BaseStrategy
      # @rbs left_query_class: Class
      # @rbs right_query_class: Class
      # @rbs return: void
      def validate_query_classes(left_query_class, right_query_class)
        unless left_query_class.respond_to?(:<) && right_query_class.respond_to?(:<)
          raise ArgumentError, "Cannot compose #{left_query_class} and #{right_query_class}, are they both classes? If you want to use instances use `.merge_instances`"
        end
      end

      # @rbs left_query_class: Class
      # @rbs right_query_class: Class
      # @rbs return: Hash[Symbol, Literal::Property]
      def collect_properties(left_query_class, right_query_class)
        props = {}
        props.merge!(left_query_class.literal_properties.properties_index) if left_query_class < Quo::Query
        props.merge!(right_query_class.literal_properties.properties_index) if right_query_class < Quo::Query
        props
      end

      # @rbs chosen_superclass: Class
      # @rbs props: Hash[Symbol, Literal::Property]
      # @rbs return: Class & Quo::ComposedQuery
      def create_composed_class(chosen_superclass, props)
        Class.new(chosen_superclass) do
          include Quo::ComposedQuery

          class << self
            attr_reader :_composing_joins, :_left_specification, :_right_specification, :_left_query, :_right_query

            # @rbs return: String
            def inspect
              left_desc = quo_operand_desc(_left_query)
              right_desc = quo_operand_desc(_right_query)
              klass_name = determine_class_name
              "#{klass_name}<Quo::ComposedQuery>[#{left_desc}, #{right_desc}]"
            end

            # @rbs operand: Class
            # @rbs return: String
            def quo_operand_desc(operand)
              if operand < Quo::ComposedQuery
                operand.inspect
              else
                operand.name || operand.superclass&.name || "(anonymous)"
              end
            end

            private

            # @rbs return: String
            def determine_class_name
              if self < Quo::RelationBackedQuery
                Quo.relation_backed_query_base_class.name
              else
                Quo.collection_backed_query_base_class.name
              end
            end
          end

          props.each do |name, property|
            prop(
              name,
              property.type,
              property.kind,
              reader: property.reader,
              writer: property.writer,
              default: property.default
            )
          end
        end
      end

      # @rbs klass: Class
      # @rbs left_query_class: Class
      # @rbs right_query_class: Class
      # @rbs joins: Symbol | Hash[Symbol, untyped] | Array[Symbol | Hash[Symbol, untyped]]?
      # @rbs left_spec: Quo::RelationBackedQuerySpecification?
      # @rbs right_spec: Quo::RelationBackedQuerySpecification?
      # @rbs return: void
      def assign_query_metadata(klass, left_query_class, right_query_class, joins, left_spec, right_spec)
        # merge spec and joins
        left_joins = left_spec ? left_spec[:joins] : []
        left_joins = left_joins.is_a?(Array) ? left_joins : [left_joins]
        joins = joins.is_a?(Array) ? joins : [joins] if joins
        merge_left_joins = joins ? joins + left_joins : left_joins

        klass.instance_variable_set(:@_composing_joins, merge_left_joins)
        klass.instance_variable_set(:@_left_specification, left_spec)
        klass.instance_variable_set(:@_right_specification, right_spec)
        klass.instance_variable_set(:@_left_query, left_query_class)
        klass.instance_variable_set(:@_right_query, right_query_class)
      end
    end
  end
end
