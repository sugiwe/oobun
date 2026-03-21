require 'rails_helper'

RSpec.describe Post, type: :model do
  describe "通知の生成" do
    let(:thread) { create(:correspondence_thread, :free) }
    let(:author) { create(:user) }
    let(:member) { create(:user) }
    let(:subscriber) { create(:user) }

    before do
      create(:membership, thread: thread, user: author)
      create(:membership, thread: thread, user: member)
      create(:subscription, thread: thread, user: subscriber)
    end

    context "公開済み投稿が作成された場合" do
      it "通知が作成される" do
        expect {
          create(:post, thread: thread, user: author, status: :published)
        }.to change(Notification, :count).by(2)

        expect(member.notifications.count).to eq(1)
        expect(subscriber.notifications.count).to eq(1)
        expect(author.notifications.count).to eq(0)
      end
    end

    context "下書き投稿が作成された場合" do
      it "通知が作成されない" do
        expect {
          create(:post, thread: thread, user: author, status: :draft)
        }.not_to change(Notification, :count)
      end
    end

    context "下書きから公開に更新された場合" do
      it "通知は作成されない（createのみトリガー）" do
        post = create(:post, thread: thread, user: author, status: :draft)

        expect {
          post.update!(status: :published)
        }.not_to change(Notification, :count)
      end
    end
  end
end
