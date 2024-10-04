# frozen_string_literal: true

# A query to fetch new unread comments that are on a particular author's posts.
# Takes an `author_id` option argument
class NewCommentsForAuthorQuery < Quo::RelationBackedQuery
  prop :author_id, Integer

  def query
    UnreadCommentsQuery.new + Comment.joins(post: :author).where(authors: {id: author_id})
  end
end
