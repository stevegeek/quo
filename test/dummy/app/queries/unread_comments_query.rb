# frozen_string_literal: true

class UnreadCommentsQuery < Quo::Query
  def query
    Comment.where(read: false)
  end
end
