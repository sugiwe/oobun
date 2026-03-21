module NotificationsHelper
  def notification_text(notification)
    actor_name = notification.actor&.display_name || "削除済みユーザー"

    case notification.action
    when "new_post"
      "#{actor_name} が「#{notification.params['thread_title']}」に投稿しました"
    when "welcome"
      "coconikkiへようこそ！"
    else
      "通知"
    end
  end

  def notification_preview(notification)
    case notification.action
    when "new_post"
      notification.params['post_preview']
    when "welcome"
      "coconikkiの使い方を見てみましょう"
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
