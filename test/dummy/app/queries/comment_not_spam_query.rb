# frozen_string_literal: true

class CommentNotSpamQuery < Quo::Query
  def query
    Comment.where("spam_score < ?", 0.5)
  end
end
