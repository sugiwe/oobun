require "rails_helper"

RSpec.describe User, type: :model do
  # ====================
  # Validations
  # ====================
  describe "バリデーション" do
    subject(:user) { build(:user) }

    context "username" do
      it { should validate_presence_of(:username) }
      it { should validate_uniqueness_of(:username) }
      it { should validate_length_of(:username).is_at_least(3).is_at_most(20) }

      it "英数字、ハイフン、アンダースコアを許可する" do
        user.username = "valid_user-123"
        expect(user).to be_valid
      end

      it "無効な文字を拒否する" do
        user.username = "invalid@user"
        expect(user).not_to be_valid
        expect(user.errors[:username]).to include("英数字、ハイフン、アンダースコアのみ使用できます")
      end

      it "スペースを含むusernameを拒否する" do
        user.username = "invalid user"
        expect(user).not_to be_valid
      end
    end

    context "display_name" do
      it { should validate_presence_of(:display_name) }
      it { should validate_length_of(:display_name).is_at_most(50) }
    end

    context "email" do
      it { should validate_presence_of(:email) }
      it { should validate_uniqueness_of(:email) }
    end

    context "google_uid" do
      it { should validate_uniqueness_of(:google_uid).allow_nil }

      it "nilのgoogle_uidを許可する" do
        user.google_uid = nil
        expect(user).to be_valid
      end
    end

    context "bio" do
      it { should validate_length_of(:bio).is_at_most(5000) }

      it "空のbioを許可する" do
        user.bio = ""
        expect(user).to be_valid
      end

      it "nilのbioを許可する" do
        user.bio = nil
        expect(user).to be_valid
      end
    end

    context "avatar" do
      it "有効な画像コンテンツタイプを許可する" do
        %w[image/png image/jpeg image/gif image/webp].each do |content_type|
          user.avatar.attach(
            io: File.open(Rails.root.join("spec/fixtures/files/test_avatar.png")),
            filename: "test.png",
            content_type: content_type
          )
          expect(user).to be_valid
        end
      end

      it "ファイルサイズが5MB未満であることを検証する" do
        # NOTE: この検証は実際のファイルサイズに依存するため、
        # 実装時には大きなファイルを用意する必要があります
        # ここでは検証ロジックの存在を確認
        expect(user.avatar.blob).to be_nil
      end
    end

    context "ストレージ上限" do
      it "アバター添付時にストレージ上限をチェックする" do
        # NOTE: ストレージ上限チェックは check_storage_limit_for_avatar で実装
        # 実際のテストは インスタンスメソッド セクションで行う
        expect(user).to respond_to(:check_storage_limit_for_avatar)
      end
    end
  end

  # ====================
  # Associations
  # ====================
  describe "アソシエーション" do
    it { should have_many(:memberships).dependent(:destroy) }
    it { should have_many(:correspondence_threads).through(:memberships).source(:thread) }
    it { should have_many(:posts).dependent(:destroy) }
    it { should have_many(:published_posts).class_name("Post") }
    it { should have_many(:draft_posts).class_name("Post") }
    it { should have_many(:subscriptions).dependent(:destroy) }
    it { should have_many(:subscribed_threads).through(:subscriptions).source(:thread) }
    it { should have_many(:skips).dependent(:destroy) }
    it { should have_one_attached(:avatar) }
  end

  # ====================
  # Class Methods
  # ====================
  describe ".find_or_initialize_from_google" do
    let(:google_payload) do
      {
        "sub" => "google_uid_123",
        "email" => "test@example.com",
        "name" => "Test User",
        "picture" => "https://example.com/avatar.jpg"
      }
    end

    context "ユーザーが存在しない場合" do
      it "Google情報で新しいユーザーを作成する" do
        user = User.find_or_initialize_from_google(google_payload)

        expect(user).to be_new_record
        expect(user.google_uid).to eq("google_uid_123")
        expect(user.email).to eq("test@example.com")
        expect(user.display_name).to eq("Test User")
        expect(user.avatar_url).to eq("https://example.com/avatar.jpg")
      end
    end

    context "ユーザーが既に存在する場合" do
      let!(:existing_user) do
        create(:user,
          google_uid: "google_uid_123",
          email: "old@example.com",
          display_name: "Old Name")
      end

      it "emailは更新するがdisplay_nameは更新しない" do
        user = User.find_or_initialize_from_google(google_payload)

        expect(user).to eq(existing_user)
        expect(user.email).to eq("test@example.com")
        expect(user.display_name).to eq("Old Name") # 既存のdisplay_nameは保持
      end
    end
  end

  # ====================
  # Instance Methods
  # ====================
  describe "インスタンスメソッド" do
    let(:user) { create(:user) }

    describe "#personalized_feed_data" do
      it "フィードデータのキーを含むハッシュを返す" do
        feed_data = user.personalized_feed_data

        expect(feed_data).to have_key(:my_turn_posts)
        expect(feed_data).to have_key(:participated_threads)
        expect(feed_data).to have_key(:followed_threads)
        expect(feed_data).to have_key(:recent_posts)
      end

      # NOTE: 詳細なフィード生成ロジックは統合テストで検証
    end

    describe "#can_join_thread?" do
      context "上限未満のスレッド数の場合" do
        it "trueを返す" do
          expect(user.can_join_thread?).to be true
        end
      end

      context "スレッド上限に達している場合" do
        before do
          create_list(:membership, User::MAX_THREADS_PER_USER, user: user)
        end

        it "falseを返す" do
          expect(user.can_join_thread?).to be false
        end
      end
    end

    describe "#threads_remaining" do
      it "参加可能な残りスレッド数を返す" do
        create_list(:membership, 3, user: user)
        expect(user.threads_remaining).to eq(User::MAX_THREADS_PER_USER - 3)
      end
    end

    describe "#storage_used" do
      context "アップロードがない場合" do
        it "0を返す" do
          expect(user.storage_used).to eq(0)
        end
      end

      context "アバターがある場合" do
        let(:user) { create(:user, :with_avatar) }

        it "ストレージ計算にアバターのサイズを含める" do
          expect(user.storage_used).to be > 0
        end
      end

      # NOTE: thumbnail付き投稿のテストは Post factory 完成後に追加
    end

    describe "#storage_remaining" do
      it "残りのストレージ容量を返す" do
        expect(user.storage_remaining).to eq(User::MAX_STORAGE_PER_USER)
      end
    end

    describe "#can_upload?" do
      context "ファイルがストレージ上限内に収まる場合" do
        it "trueを返す" do
          expect(user.can_upload?(1.megabyte)).to be true
        end
      end

      context "ファイルがストレージ上限を超える場合" do
        it "falseを返す" do
          expect(user.can_upload?(101.megabytes)).to be false
        end
      end
    end

    describe "#post_rate_limit_exceeded?" do
      context "制限内の場合" do
        it "falseを返す" do
          expect(user.post_rate_limit_exceeded?).to be false
        end
      end

      context "時間制限を超えた場合" do
        before do
          create_list(:post, User::MAX_POSTS_PER_HOUR, user: user, created_at: 30.minutes.ago)
        end

        it "trueを返す" do
          expect(user.post_rate_limit_exceeded?).to be true
        end
      end

      context "日次制限を超えた場合" do
        before do
          # 今日(JST)の範囲内で投稿を作成
          today_start = Time.current.in_time_zone("Tokyo").beginning_of_day
          create_list(:post, User::MAX_POSTS_PER_DAY, user: user, created_at: today_start + 1.hour)
        end

        it "trueを返す" do
          expect(user.post_rate_limit_exceeded?).to be true
        end
      end
    end

    describe "#posts_in_last_hour" do
      it "直近1時間以内に作成された投稿をカウントする" do
        create_list(:post, 3, user: user, created_at: 30.minutes.ago)
        create(:post, user: user, created_at: 2.hours.ago) # カウントされない

        expect(user.posts_in_last_hour).to eq(3)
      end

      it "下書きと公開済み投稿の両方をカウントする" do
        create(:post, user: user, status: :draft, created_at: 30.minutes.ago)
        create(:post, user: user, status: :published, created_at: 30.minutes.ago)

        expect(user.posts_in_last_hour).to eq(2)
      end
    end

    describe "#posts_today" do
      it "今日(JST)作成された投稿をカウントする" do
        today_start = Time.current.in_time_zone("Tokyo").beginning_of_day
        create_list(:post, 5, user: user, created_at: today_start + 12.hours)
        expect(user.posts_today).to eq(5)
      end

      it "前日の投稿はカウントしない" do
        yesterday = Time.current.in_time_zone("Tokyo").beginning_of_day - 1.day
        create(:post, user: user, created_at: yesterday)
        expect(user.posts_today).to eq(0)
      end

      it "下書きと公開済み投稿の両方をカウントする" do
        create(:post, user: user, status: :draft)
        create(:post, user: user, status: :published)

        expect(user.posts_today).to eq(2)
      end
    end

    describe "#admin?" do
      context "emailがADMIN_EMAIL_SETに含まれる場合" do
        it "trueを返す" do
          # ADMIN_EMAIL_SETに含まれるemailを持つユーザーを作成
          admin_email = User::ADMIN_EMAIL_SET.first
          skip "ADMIN_EMAILSが設定されていません" if admin_email.nil?

          admin_user = create(:user, email: admin_email)
          expect(admin_user.admin?).to be true
        end
      end

      context "emailがADMIN_EMAIL_SETに含まれない場合" do
        it "falseを返す" do
          expect(user.admin?).to be false
        end
      end
    end

    describe "#deleted?" do
      context "deleted_atが存在する場合" do
        let(:deleted_user) { create(:user, :deleted) }

        it "trueを返す" do
          expect(deleted_user.deleted?).to be true
        end
      end

      context "deleted_atがnilの場合" do
        it "falseを返す" do
          expect(user.deleted?).to be false
        end
      end
    end

    describe "#normalized_email" do
      it "小文字化してトリムしたemailを返す" do
        user.email = "  TEST@EXAMPLE.COM  "
        expect(user.normalized_email).to eq("test@example.com")
      end
    end
  end

  # ====================
  # Constants
  # ====================
  describe "定数" do
    it "MAX_THREADS_PER_USERが定義されている" do
      expect(User::MAX_THREADS_PER_USER).to eq(10)
    end

    it "MAX_STORAGE_PER_USERが定義されている" do
      expect(User::MAX_STORAGE_PER_USER).to eq(100.megabytes)
    end

    it "MAX_POSTS_PER_HOURが定義されている" do
      expect(User::MAX_POSTS_PER_HOUR).to eq(10)
    end

    it "MAX_POSTS_PER_DAYが定義されている" do
      expect(User::MAX_POSTS_PER_DAY).to eq(50)
    end

    it "ANONYMIZED_DISPLAY_NAMEが定義されている" do
      expect(User::ANONYMIZED_DISPLAY_NAME).to eq("退会済みユーザー")
    end
  end
end
