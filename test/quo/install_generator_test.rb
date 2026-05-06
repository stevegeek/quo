# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/quo/install/install_generator"

class Quo::Generators::InstallGeneratorTest < Rails::Generators::TestCase
  tests Quo::Generators::InstallGenerator
  destination File.expand_path("../tmp/generator_dest", __dir__)
  setup :prepare_destination

  test "copies the skill into .claude/skills/quo/" do
    run_generator

    assert_file ".claude/skills/quo/SKILL.md" do |contents|
      assert_match(/name: quo/, contents)
      assert_match(/Targets Quo `~> 1\.0`/, contents)
      assert_match(/Composition: class-level vs instance-level/, contents)
    end
    assert_file ".claude/skills/quo/README.md"
    assert_file ".claude/skills/quo/references/COMPOSITION.md"
    assert_file ".claude/skills/quo/references/QUERY_TYPES.md"
    assert_file ".claude/skills/quo/references/PAGINATION.md"
    assert_file ".claude/skills/quo/references/TRANSFORMERS.md"
    assert_file ".claude/skills/quo/references/API_REFERENCE.md"
  end

  test "does not write CLAUDE.md by default" do
    run_generator
    assert_no_file "CLAUDE.md"
  end

  test "--with-claude-md creates CLAUDE.md when missing" do
    run_generator ["--with-claude-md"]
    assert_file "CLAUDE.md" do |contents|
      assert_match(/^## Quo$/, contents)
      assert_match(%r{\.claude/skills/quo/SKILL\.md}, contents)
    end
  end

  test "--with-claude-md appends to an existing CLAUDE.md" do
    File.write(File.join(destination_root, "CLAUDE.md"), "# Project\n\nExisting content.\n")

    run_generator ["--with-claude-md"]

    contents = File.read(File.join(destination_root, "CLAUDE.md"))
    assert_match(/^# Project$/, contents)
    assert_match(/Existing content\./, contents)
    assert_match(/^## Quo$/, contents)
  end

  test "--with-claude-md is idempotent — does not double-append the section" do
    run_generator ["--with-claude-md"]
    first = File.read(File.join(destination_root, "CLAUDE.md"))

    run_generator ["--with-claude-md", "--force"]
    second = File.read(File.join(destination_root, "CLAUDE.md"))

    assert_equal first, second, "CLAUDE.md should not change on re-run"
    assert_equal 1, second.scan(/^## Quo$/).count
  end
end
