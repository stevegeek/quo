# frozen_string_literal: true

# rbs_inline: enabled

require_relative "composing"

module Quo
  # Mixin for queries composed of two child queries
  module ComposedQuery
    # Class-level methods shared by every composed query class. Defined once
    # here and extended onto each anon class via the `included` hook below
    # rather than being re-defined on every Class.new in the composer.
    module ClassMethods
      attr_reader :_composing_joins, :_left_specification, :_right_specification, :_left_query, :_right_query

      # @rbs return: String
      def inspect
        left_desc = quo_operand_desc(_left_query)
        right_desc = quo_operand_desc(_right_query)
        klass_name = if self < Quo::RelationBackedQuery
          Quo.relation_backed_query_base_class.name
        else
          Quo.collection_backed_query_base_class.name
        end
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
    end

    # @rbs base: Class
    # @rbs return: void
    def self.included(base)
      base.extend(ClassMethods)
    end

    # @rbs override
    def query
      merge_left_and_right
    end

    # @rbs override
    def inspect
      klass_name = is_a?(Quo::RelationBackedQuery) ? Quo::RelationBackedQuery.name : Quo::CollectionBackedQuery.name
      "#{klass_name}<Quo::ComposedQuery>[#{self.class.quo_operand_desc(left.class)}, #{self.class.quo_operand_desc(right.class)}](#{super})"
    end

    private

    # @rbs return: Hash[Symbol, untyped]
    def child_options(query_class)
      names = property_names(query_class)
      to_h.slice(*names)
    end

    # @rbs return: Array[Symbol]
    def property_names(query_class)
      query_class.literal_properties.properties_index.keys
    end

    # @rbs return: Quo::Query | ::ActiveRecord::Relation
    def left
      lq = self.class._left_query
      return lq if is_relation?(lq)
      options = child_options(lq)
      spec = self.class._left_specification
      options[:_specification] = spec if spec && lq < Quo::RelationBackedQuery
      lq.new(**options)
    end

    # @rbs return: Quo::Query | ::ActiveRecord::Relation
    def right
      rq = self.class._right_query
      return rq if is_relation?(rq)
      options = child_options(rq)
      spec = self.class._right_specification
      options[:_specification] = spec if spec && rq < Quo::RelationBackedQuery
      rq.new(**options)
    end

    # @rbs return: ActiveRecord::Relation | CollectionBackedQuery
    def merge_left_and_right
      left_rel = quo_unwrap_unpaginated_query(left)
      right_rel = quo_unwrap_unpaginated_query(right)

      if both_relations?(left_rel, right_rel)
        merge_active_record_relations(left_rel, right_rel)
      elsif left_relation_right_enumerable?(left_rel, right_rel)
        left_rel.to_a + right_rel
      elsif left_enumerable_right_relation?(left_rel, right_rel) && left_rel.respond_to?(:+)
        left_rel + right_rel.to_a
      elsif left_rel.respond_to?(:+)
        left_rel + right_rel
      else
        raise ArgumentError, "Cannot merge #{left.class} with #{right.class}"
      end
    end

    # @rbs left_rel: ActiveRecord::Relation
    # @rbs right_rel: ActiveRecord::Relation
    # @rbs return: ActiveRecord::Relation
    def merge_active_record_relations(left_rel, right_rel)
      joins = self.class._composing_joins
      left_rel = left_rel.joins(joins) if joins
      left_rel.merge(right_rel)
    end

    # @rbs rel: untyped
    # @rbs return: bool
    def is_relation?(rel)
      rel.is_a?(::ActiveRecord::Relation)
    end

    # @rbs left: untyped
    # @rbs right: untyped
    # @rbs return: bool
    def both_relations?(left, right)
      is_relation?(left) && is_relation?(right)
    end

    # @rbs left: untyped
    # @rbs right: untyped
    # @rbs return: bool
    def left_relation_right_enumerable?(left, right)
      is_relation?(left) && !is_relation?(right)
    end

    # @rbs left: untyped
    # @rbs right: untyped
    # @rbs return: bool
    def left_enumerable_right_relation?(left, right)
      !is_relation?(left) && is_relation?(right)
    end
  end
end
