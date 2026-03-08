# 空スレッドの自動削除ジョブ
# 30日経過して投稿が1つもない（下書き含む）スレッドを自動的に削除する
class AutoDeleteEmptyThreadsJob < ApplicationJob
  queue_as :default

  def perform
    # 30日経過 AND 全投稿（下書き含む）が0件のスレッドを取得
    CorrespondenceThread
      .where("created_at <= ?", CorrespondenceThread::AUTO_DELETE_DAYS_THRESHOLD.days.ago)
      .where("NOT EXISTS (SELECT 1 FROM posts WHERE posts.thread_id = threads.id)")
      .find_each do |thread|
        Rails.logger.info "Auto-deleting empty thread: #{thread.slug} (status: #{thread.status}, created #{thread.days_since_creation} days ago)"
        thread.destroy!
      end
  end
end
