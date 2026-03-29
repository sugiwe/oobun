require "rails_helper"

RSpec.describe EmailNotificationJob, type: :job do
  let(:user) { create(:user) }
  let(:actor) { create(:user) }
  let(:thread_instance) { create(:correspondence_thread, :free) }
  let(:post_instance) { create(:post, thread: thread_instance, user: actor) }

  describe "#perform" do
    context "test_notification の場合" do
      let(:notification) do
        create(:notification,
          user: user,
          actor: user,
          notifiable: user,
          action: :test_notification,
          params: { message: "テストメッセージ" })
      end

      context "即時配信モード" do
        before do
          user.create_notification_setting(
            email_mode: :realtime,
            email_count_this_month: 0,
            email_count_reset_at: Date.current.beginning_of_month
          )
        end

        it "テストメールが送信される" do
          expect {
            described_class.perform_now(notification.id)
          }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
            .with("UserMailer", "test_notification", "deliver_now", { args: [ notification ] })

          # 残数が1減る
          user.notification_setting.reload
          expect(user.notification_setting.remaining_emails_this_month).to eq(99)
        end

        it "上限到達時はメール送信されない" do
          user.notification_setting.update!(email_count_this_month: 100)

          expect {
            described_class.perform_now(notification.id)
          }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
        end
      end

      context "ダイジェスト配信モード" do
        before do
          user.create_notification_setting(
            email_mode: :digest,
            digest_time: Time.zone.parse("08:00:00")
          )
        end

        it "メール送信されない" do
          expect {
            described_class.perform_now(notification.id)
          }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
        end
      end

      context "メール通知なしモード" do
        before do
          user.create_notification_setting(
            email_mode: :off,
            digest_time: Time.zone.parse("08:00:00")
          )
        end

        it "メール送信されない" do
          expect {
            described_class.perform_now(notification.id)
          }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
        end
      end
    end

    context "new_post の場合" do
      let(:notification) do
        create(:notification,
          user: user,
          actor: actor,
          notifiable: post_instance,
          action: :new_post,
          params: { post_preview: post_instance.body[0..100] })
      end

      context "即時配信モード" do
        before do
          user.create_notification_setting(
            email_mode: :realtime,
            email_count_this_month: 0,
            email_count_reset_at: Date.current.beginning_of_month
          )
        end

        it "投稿通知メールが送信される" do
          expect {
            described_class.perform_now(notification.id)
          }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
            .with("UserMailer", "new_post_notification", "deliver_now", { args: [ notification ] })

          # 残数が1減る
          user.notification_setting.reload
          expect(user.notification_setting.remaining_emails_this_month).to eq(99)
        end
      end

      context "ダイジェスト配信モード" do
        before do
          user.create_notification_setting(
            email_mode: :digest,
            digest_time: Time.zone.parse("08:00:00")
          )
        end

        it "メール送信されない（DailyDigestJobで処理される）" do
          expect {
            described_class.perform_now(notification.id)
          }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
        end
      end
    end
  end
end
