# frozen_string_literal: true

module Quo
  module Utilities
    module Callstack
      def debug_callstack
        return unless Quo.configuration&.query_show_callstack_size&.positive? && Rails.env.development?
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
end
