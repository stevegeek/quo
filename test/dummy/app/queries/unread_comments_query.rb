# frozen_string_literal: true

# A query to fetch all the comments that are not yet marked as read
class UnreadCommentsQuery < Quo::RelationBackedQuery
  def query
    # Comment.where(read: false)
    Comment.unread # TODO: flip as Comment.query_scope :unread, -> { UnreadCommentsQuery.new }
  end
end
