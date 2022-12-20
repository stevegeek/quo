# frozen_string_literal: true

# A query to fetch all the comments that are not yet marked as read
class UnreadCommentsQuery < Quo::Query
  def query
    Comment.where(read: false)
  end
end
