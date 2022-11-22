# frozen_string_literal: true

class AddTestModels < ActiveRecord::Migration[6.0]
  def change
    create_table :authors do |t|
      t.string :name
      t.timestamps
    end

    create_table :posts do |t|
      t.string :title
      t.text :body
      t.references :author
      t.timestamps
    end

    create_table :comments do |t|
      t.text :body
      t.boolean :read, default: false
      t.numeric :spam_score
      t.references :post
      t.timestamps
    end
  end
end
