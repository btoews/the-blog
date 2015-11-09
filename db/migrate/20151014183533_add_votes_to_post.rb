class AddVotesToPost < ActiveRecord::Migration
  def change
    add_column :posts, :votes, :integer, null: false, default: 1
  end
end
