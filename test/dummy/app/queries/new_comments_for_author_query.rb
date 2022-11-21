# frozen_string_literal: true

class NewCommentsForAuthorQuery < Quo::Query
  def query
    UnreadCommentsQuery.new + Comment.joins(post: :author).where(authors: {id: options[:author_id]})
  end
end
