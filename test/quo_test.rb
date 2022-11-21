# frozen_string_literal: true

require "test_helper"

class QuoTest < ActiveSupport::TestCase
  test "it has a version number" do
    refute_nil ::Quo::VERSION
  end
end
