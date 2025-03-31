# frozen_string_literal: true

module Quo
  module Composing
    # Base class for all composition strategies
    class BaseStrategy
      def applicable?(left, right)
        raise NoMethodError, "Subclasses must implement #applicable?"
      end

      def compose(...)
        raise NoMethodError, "Subclasses must implement #compose"
      end
    end
  end
end
