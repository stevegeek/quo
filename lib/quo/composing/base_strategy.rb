# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  module Composing
    # Base class for all composition strategies
    class BaseStrategy
      # @rbs left: untyped
      # @rbs right: untyped
      # @rbs return: bool
      def applicable?(left, right)
        raise NoMethodError, "Subclasses must implement #applicable?"
      end

      # @rbs return: untyped
      def compose(...)
        raise NoMethodError, "Subclasses must implement #compose"
      end
    end
  end
end
