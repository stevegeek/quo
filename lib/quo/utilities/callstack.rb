# frozen_string_literal: true

module Quo
  module Utilities
    module Callstack
      def debug_callstack
        return unless Rails.env.development?
        callstack_size = Quo.query_show_callstack_size
        return unless callstack_size&.positive?
        working_dir = Dir.pwd
        exclude = %r{/(gems/|rubies/|query\.rb)}
        stack = Kernel.caller.grep_v(exclude).map { |l| l.gsub(working_dir + "/", "") }
        stack_to_display = stack[0..callstack_size]
        message = "\n[Query stack]: -> #{stack_to_display&.join("\n               &> ")}\n"
        message += " (truncated to #{callstack_size} most recent)" if callstack_size && stack.size > callstack_size
        logger = Quo.logger&.call
        logger&.info(message)
      end
    end
  end
end
