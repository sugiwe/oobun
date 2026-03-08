# 空スレッドの自動削除ジョブ
# 30日経過して投稿が1つもないスレッドを自動的に削除する（公開状態問わず）
class AutoDeleteEmptyThreadsJob < ApplicationJob
  queue_as :default

  def perform
    # 30日経過 AND 投稿が0件のスレッドを取得（公開状態問わず）
    CorrespondenceThread
      .where("created_at <= ?", CorrespondenceThread::AUTO_DELETE_DAYS_THRESHOLD.days.ago)
      .where("(SELECT COUNT(*) FROM posts WHERE posts.thread_id = threads.id AND posts.status = 'published') = 0")
      .find_each do |thread|
        Rails.logger.info "Auto-deleting empty thread: #{thread.slug} (status: #{thread.status}, created #{thread.days_since_creation} days ago)"
        thread.destroy!
      end
  end
end
