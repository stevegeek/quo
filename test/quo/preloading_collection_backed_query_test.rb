# frozen_string_literal: true

require_relative "../test_helper"

class Quo::ReloadableCollectionBackedQueryTest < ActiveSupport::TestCase
  def create_query_class
    Class.new(Quo::CollectionBackedQuery) do
      include Quo::Preloadable

      def collection
        [1, 2, 3]
      end
    end
  end

  test "#includes" do
    author = Author.create!(name: "John")
    q = create_query_class.wrap([author]).new
    q = q.includes(:posts)
    assert q.results.first.posts.loaded?
  end

  test "#preload" do
    author = Author.create!(name: "John")
    q = create_query_class.wrap([author]).new
    q = q.preload(:posts)
    assert q.results.first.posts.loaded?
  end
end
