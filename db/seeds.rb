# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# 開発環境用テストユーザー
if Rails.env.development?
  test_users = [
    { username: "alice", display_name: "アリス", email: "alice@example.com", bio: "文通好きです" },
    { username: "bob", display_name: "ボブ", email: "bob@example.com", bio: "日記を書くのが趣味" },
    { username: "charlie", display_name: "チャーリー", email: "charlie@example.com", bio: "読書と散歩が好き" },
    { username: "diana", display_name: "ダイアナ", email: "diana@example.com", bio: "旅行が大好きです" },
    { username: "eve", display_name: "イブ", email: "eve@example.com", bio: "料理とカメラが趣味" }
  ]

  test_users.each do |attrs|
    User.find_or_create_by!(username: attrs[:username]) do |user|
      user.display_name = attrs[:display_name]
      user.email = attrs[:email]
      user.bio = attrs[:bio]
      user.google_uid = "dev_#{attrs[:username]}"
    end
  end

  puts "✅ 開発用テストユーザー #{test_users.size}人を作成しました"
end

# サンプル交換日記（開発環境・本番環境共通）
load Rails.root.join("db", "seeds", "sample_threads.rb")
