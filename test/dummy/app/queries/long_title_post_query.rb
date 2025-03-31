# frozen_string_literal: true

# A query to fetch posts with titles longer than a specified length
class LongTitlePostQuery < Quo::RelationBackedQuery
  prop :min_length, Integer, default: -> { 30 }

  def query
    posts = Post.arel_table
    length_function = Arel::Nodes::NamedFunction.new('LENGTH', [posts[:title]])
    Post.where(length_function.gt(min_length))
  end
end