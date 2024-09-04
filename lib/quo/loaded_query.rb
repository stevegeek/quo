# frozen_string_literal: true

module Quo
  class LoadedQuery < Quo::EagerQuery
    prop :collection, _Any, writer: false, shadow_check: false
  end
end
