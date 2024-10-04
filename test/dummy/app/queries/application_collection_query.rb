# frozen_string_literal: true

# This is configured as the base query class for the applications queries. See the Quo initializer
class ApplicationCollectionQuery < Quo::CollectionBackedQuery
  def hello
    "collection"
  end
end
