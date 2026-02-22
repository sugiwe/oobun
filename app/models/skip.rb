class Skip < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :thread, class_name: "CorrespondenceThread", foreign_key: :thread_id

  # Callbacks
  after_create :update_thread_turn

  # Scopes
  default_scope -> { order(created_at: :desc) }

  private

  def update_thread_turn
    # スキップしたユーザーを last_post_user_id にセットして次のターンに進める
    thread.update!(last_post_user_id: user_id)
  end
end
