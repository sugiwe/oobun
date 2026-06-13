require "rails_helper"

RSpec.describe "Invitations", type: :system do
  describe "招待ページのSEO設定" do
    let(:user) { create(:user) }
    let(:correspondence_thread) { create(:correspondence_thread, :free) }
    let(:invitation) { create(:invitation, thread: correspondence_thread, invited_by: user) }

    it "招待ページにnoindexメタタグが設定されている" do
      visit invitation_path(invitation.token)

      expect(page).to have_css('meta[name="robots"][content="noindex"]', visible: false)
    end

    it "招待ページのタイトルが正しく表示される" do
      visit invitation_path(invitation.token)

      expect(page).to have_title("#{correspondence_thread.title}への招待 - coconikki")
    end
  end

  describe "招待ページの表示" do
    let(:user) { create(:user) }
    let(:correspondence_thread) { create(:correspondence_thread, :free, title: "テスト交換日記") }
    let(:invitation) { create(:invitation, thread: correspondence_thread, invited_by: user) }

    context "未ログインユーザーの場合" do
      it "ログインボタンが表示される" do
        visit invitation_path(invitation.token)

        expect(page).to have_content("「テスト交換日記」への招待")
        expect(page).to have_content("@#{user.username}")
        expect(page).to have_content("テスト交換日記")
        expect(page).to have_content("参加するにはログインが必要です")
        expect(page).to have_link("ログインして参加する", href: login_path)
      end
    end

    context "ログイン済みユーザーの場合" do
      let(:logged_in_user) { create(:user) }

      before do
        login_as(logged_in_user)
      end

      it "参加ボタンが表示される" do
        visit invitation_path(invitation.token)

        expect(page).to have_content("「テスト交換日記」への招待")
        expect(page).to have_content("@#{user.username}")
        expect(page).to have_content("テスト交換日記")
        expect(page).to have_button("この交換日記に参加する")
        expect(page).to have_link("今回は見送る", href: root_path)
      end
    end
  end
end
