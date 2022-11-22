# frozen_string_literal: true

module Quo
  module Utilities
    module Sanitize
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
    end
  end
end
