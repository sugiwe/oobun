module NotificationsHelper
  def notification_text(notification)
    actor_name = notification.actor&.display_name || "削除済みユーザー"

    case notification.action
    when "new_post"
      "#{actor_name} が「#{notification.params['thread_title']}」に投稿しました"
    when "annotation_added"
      "#{actor_name} があなたの投稿に付箋を追加しました"
    when "annotation_invalidated"
      "#{actor_name} が投稿を編集したため、あなたの付箋が表示されなくなりました"
    when "welcome"
      "coconikkiへようこそ!"
    when "test_notification"
      "テスト通知"
    else
      "通知"
    end
  end

  def notification_preview(notification)
    case notification.action
    when "new_post"
      notification.params["post_preview"]
    when "annotation_added"
      # 付箋のメモ内容をプレビュー表示
      annotation = notification.notifiable
      annotation&.body || "メモを確認してください"
    when "annotation_invalidated"
      # 付箋無効化の通知では、付箋一覧へのリンクを含める
      # HTMLは通知ビュー側で処理
      nil
    when "welcome"
      "coconikkiの使い方を見てみましょう"
    when "test_notification"
      notification.params["message"]
    else
      nil
    end
  end

  def notification_time_ago(notification)
    time_diff = Time.current - notification.created_at

    if time_diff < 1.minute
      "たった今"
    elsif time_diff < 1.hour
      "#{(time_diff / 1.minute).to_i}分前"
    elsif time_diff < 1.day
      "#{(time_diff / 1.hour).to_i}時間前"
    elsif time_diff < 1.week
      "#{(time_diff / 1.day).to_i}日前"
    elsif time_diff < 4.weeks
      "#{(time_diff / 1.week).to_i}週間前"
    else
      notification.created_at.strftime("%Y年%-m月%-d日")
    end
  end
end
