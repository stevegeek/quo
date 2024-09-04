# frozen_string_literal: true

# A query to fetch all the comments that are not spam
class CommentNotSpamQuery < Quo::Query
  prop :spam_score_threshold, _Float(0..1.0)

  def query
    Comment.where("spam_score IS NULL OR spam_score < ?", spam_score_threshold)
  end
end
