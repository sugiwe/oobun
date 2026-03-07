# 空の非公開スレッドの自動削除ジョブ
# 30日経過した非公開スレッドで、投稿が1つもないものを自動的に削除する
class AutoDeleteEmptyThreadsJob < ApplicationJob
  queue_as :default

  def perform
    # 30日経過 AND 投稿が0件の非公開スレッドを取得
    CorrespondenceThread.draft
      .where("created_at <= ?", CorrespondenceThread::AUTO_DELETE_DAYS_THRESHOLD.days.ago)
      .where("(SELECT COUNT(*) FROM posts WHERE posts.thread_id = threads.id AND posts.status = 'published') = 0")
      .find_each do |thread|
        Rails.logger.info "Auto-deleting empty thread: #{thread.slug} (created #{thread.days_since_creation} days ago)"
        thread.destroy!
      end
  end
end
