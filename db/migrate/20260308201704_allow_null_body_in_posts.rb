class AllowNullBodyInPosts < ActiveRecord::Migration[8.1]
  def change
    change_column_null :posts, :body, true
  end
end
