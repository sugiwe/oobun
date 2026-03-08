# 非公開スレッドの自動公開ジョブ
# 30日経過した非公開スレッドで、投稿が1つ以上あるものを自動的に公開する
class AutoPublishThreadsJob < ApplicationJob
  queue_as :default

  def perform
    # 30日経過 AND 公開済み投稿が1つ以上ある非公開スレッドを取得
    # (下書きのみのスレッドは対象外 = 非公開のまま放置)
    CorrespondenceThread.draft
      .where("created_at <= ?", CorrespondenceThread::AUTO_PUBLISH_DAYS_THRESHOLD.days.ago)
      .where("EXISTS (SELECT 1 FROM posts WHERE posts.thread_id = threads.id AND posts.status = 'published')")
      .find_each do |thread|
        thread.auto_publish!
      end
  end
end
