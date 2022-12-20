# frozen_string_literal: true

# A query to fetch all the comments that are not spam
class CommentNotSpamQuery < Quo::Query
  def query
    Comment.where("spam_score < ?", 0.5)
  end
end
