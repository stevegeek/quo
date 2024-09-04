# frozen_string_literal: true

class Comment < ActiveRecord::Base
  belongs_to :post

  scope :recent, proc { |since| where("created_at > ?", since || 1.week.ago) }
  scope :not_spam, proc { |score| where("spam_score IS NULL OR spam_score < ?", score || 0.5) }
end
