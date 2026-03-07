# 非公開スレッドの自動公開ジョブ
# 30日経過した非公開スレッドで、投稿が1つ以上あるものを自動的に公開する
class AutoPublishThreadsJob < ApplicationJob
  queue_as :default

  def perform
    # 30日経過 AND 投稿が1つ以上ある非公開スレッドを取得
    CorrespondenceThread.draft
      .where("created_at <= ?", CorrespondenceThread::AUTO_PUBLISH_DAYS_THRESHOLD.days.ago)
      .where("(SELECT COUNT(*) FROM posts WHERE posts.thread_id = threads.id AND posts.status = 'published') > 0")
      .find_each do |thread|
        thread.auto_publish!
      end
  end
end
