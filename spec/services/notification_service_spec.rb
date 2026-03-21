require "rails_helper"

RSpec.describe NotificationService, type: :service do
  describe ".notify_new_post" do
    let(:thread) { create(:correspondence_thread, :free) }
    let(:author) { create(:user) }
    let(:member1) { create(:user) }
    let(:member2) { create(:user) }
    let(:subscriber1) { create(:user) }
    let(:subscriber2) { create(:user) }
    let(:other_user) { create(:user) }

    before do
      # メンバーを追加
      create(:membership, thread: thread, user: author)
      create(:membership, thread: thread, user: member1)
      create(:membership, thread: thread, user: member2)

      # 購読者を追加
      create(:subscription, thread: thread, user: subscriber1)
      create(:subscription, thread: thread, user: subscriber2)
    end

    context "公開済み投稿が作成された場合" do
      # 下書きとして作成してコールバックを回避
      let(:post) { create(:post, thread: thread, user: author, status: :draft) }

      it "メンバーと購読者に通知を作成する（投稿者自身を除く）" do
        expect {
          NotificationService.notify_new_post(post)
        }.to change(Notification, :count).by(4)

        # 投稿者以外のメンバーと購読者が通知を受け取る
        expect(member1.notifications.count).to eq(1)
        expect(member2.notifications.count).to eq(1)
        expect(subscriber1.notifications.count).to eq(1)
        expect(subscriber2.notifications.count).to eq(1)

        # 投稿者自身は通知を受け取らない
        expect(author.notifications.count).to eq(0)

        # 関係のないユーザーは通知を受け取らない
        expect(other_user.notifications.count).to eq(0)
      end

      it "通知に正しいパラメータが設定される" do
        NotificationService.notify_new_post(post)

        notification = member1.notifications.first
        expect(notification.action).to eq("new_post")
        expect(notification.actor).to eq(author)
        # Postはdefault_scopeがあるため、notifiable_idとnotifiable_typeで確認
        expect(notification.notifiable_id).to eq(post.id)
        expect(notification.notifiable_type).to eq("Post")
        expect(notification.params["thread_title"]).to eq(thread.title)
        expect(notification.params["thread_slug"]).to eq(thread.slug)
        expect(notification.params["post_preview"]).to eq(post.body.truncate(100))
      end
    end

    context "メンバーと購読者が重複する場合" do
      before do
        # subscriber1がメンバーでもあるケース
        create(:membership, thread: thread, user: subscriber1)
      end

      # 下書きとして作成してコールバックを回避
      let(:post) { create(:post, thread: thread, user: author, status: :draft) }

      it "重複して通知が作成されない" do
        expect {
          NotificationService.notify_new_post(post)
        }.to change(Notification, :count).by(4)

        # subscriber1は1つだけ通知を受け取る（重複しない）
        expect(subscriber1.notifications.count).to eq(1)
      end
    end

    context "投稿本文が長い場合" do
      let(:long_body) { "あ" * 200 }
      # 下書きとして作成してコールバックを回避
      let(:post) { create(:post, thread: thread, user: author, status: :draft, body: long_body) }

      it "post_previewが100文字に切り詰められる" do
        NotificationService.notify_new_post(post)

        notification = member1.notifications.first
        expect(notification.params["post_preview"].length).to be <= 100
      end
    end
  end
end
