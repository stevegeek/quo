# frozen_string_literal: true

require "test_helper"

class Quo::Composing::BaseStrategyTest < ActiveSupport::TestCase
  def setup
    @strategy = Quo::Composing::BaseStrategy.new
  end

  test "#applicable? raises NotImplementedError for base class" do
    error = assert_raises(NoMethodError) do
      @strategy.applicable?(nil, nil)
    end
    assert_equal "Subclasses must implement #applicable?", error.message
  end

  test "#compose raises NotImplementedError for base class" do
    error = assert_raises(NoMethodError) do
      @strategy.compose
    end
    assert_equal "Subclasses must implement #compose", error.message
  end
end
