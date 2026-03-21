require "rails_helper"

RSpec.describe Notification, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:actor).class_name("User").optional }
    it { should belong_to(:notifiable) }
  end

  describe "scopes" do
    let(:user) { create(:user) }
    let!(:unread_notification) { create(:notification, user: user, read_at: nil) }
    let!(:read_notification) { create(:notification, user: user, read_at: 1.hour.ago) }

    describe ".unread" do
      it "未読の通知のみを返す" do
        expect(user.notifications.unread).to include(unread_notification)
        expect(user.notifications.unread).not_to include(read_notification)
      end
    end

    describe ".recent" do
      it "作成日時の降順で返す" do
        expect(user.notifications.recent.first).to eq(read_notification)
      end
    end
  end

  describe "enums" do
    it { should define_enum_for(:action).with_values(new_post: "new_post", welcome: "welcome").backed_by_column_of_type(:string) }
  end

  describe "#mark_as_read!" do
    let(:notification) { create(:notification, read_at: nil) }

    it "read_atを現在時刻に更新する" do
      travel_to Time.current do
        notification.mark_as_read!
        expect(notification.read_at).to eq(Time.current)
      end
    end
  end

  describe "#unread?" do
    context "未読の場合" do
      let(:notification) { create(:notification, read_at: nil) }

      it "trueを返す" do
        expect(notification.unread?).to be true
      end
    end

    context "既読の場合" do
      let(:notification) { create(:notification, read_at: 1.hour.ago) }

      it "falseを返す" do
        expect(notification.unread?).to be false
      end
    end
  end
end
