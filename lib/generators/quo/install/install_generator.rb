# frozen_string_literal: true

require "rails/generators/base"

module Quo
  module Generators
    # Installs the bundled Claude Code skill into the host application's
    # .claude/skills/quo/ directory. Optionally appends a short "Quo" section
    # to the project's top-level CLAUDE.md.
    class InstallGenerator < ::Rails::Generators::Base
      # Source the skill content directly from claude-skill/ at the gem root.
      # The generator file lives at lib/generators/quo/install/, so we go up
      # four levels to reach the gem root.
      source_root File.expand_path("../../../../claude-skill", __dir__)

      desc "Install the Quo Claude Code skill into .claude/skills/quo/"

      class_option :with_claude_md, type: :boolean, default: false,
        desc: "Append a 'Quo' section to CLAUDE.md pointing at the skill"

      CLAUDE_MD_MARKER = "## Quo"

      CLAUDE_MD_FRAGMENT = <<~MD
        #{CLAUDE_MD_MARKER}

        This project uses the [Quo gem](https://github.com/stevegeek/quo) for
        query objects. See `.claude/skills/quo/SKILL.md` for usage guidance,
        including the class-vs-instance composition rules.
      MD

      def copy_skill
        directory ".", ".claude/skills/quo"
      end

      def maybe_append_claude_md
        return unless options[:with_claude_md]

        path = "CLAUDE.md"
        full_path = File.join(destination_root, path)
        if File.exist?(full_path)
          if File.read(full_path).include?(CLAUDE_MD_MARKER)
            say_status :skip, "#{path} already contains '#{CLAUDE_MD_MARKER}' section", :yellow
          else
            append_to_file path, "\n#{CLAUDE_MD_FRAGMENT}"
          end
        else
          create_file path, CLAUDE_MD_FRAGMENT
        end
      end

      def show_post_install_message
        say ""
        say "Quo skill installed at .claude/skills/quo/", :green
        say "Claude Code will pick it up automatically on the next session.", :green
        if options[:with_claude_md]
          say "CLAUDE.md updated with a pointer to the skill.", :green
        end
        say ""
        say "Run with --force after upgrading Quo to refresh the skill content."
      end
    end
  end
end
