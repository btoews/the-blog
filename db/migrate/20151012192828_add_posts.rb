class AddPosts < ActiveRecord::Migration
  def change
    create_table :posts do |t|
      t.string :name
      t.text :body
      t.timestamps null: false
    end
  end
end
