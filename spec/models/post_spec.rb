require 'rails_helper'

RSpec.describe Post, type: :model do
  # NOTE: 投稿公開時の通知作成フローについて
  # - 詳細な通知ロジックのテスト: spec/services/notification_service_spec.rb
  # - E2Eでの通知フロー検証: システムテストで実装予定 (TODO)
end
