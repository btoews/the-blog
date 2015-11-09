class AddVotes < ActiveRecord::Migration
  def change
    create_table :votes do |t|
      t.integer :user_id, null: false
      t.integer :post_id, null: false
      t.integer :value,   null: false
      t.timestamps    null: false
    end
  end
end
