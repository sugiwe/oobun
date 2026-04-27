require "rails_helper"

RSpec.describe Annotation, type: :model do
  describe "associations" do
    it { should belong_to(:post) }
    it { should belong_to(:user) }
  end

  describe "validations" do
    describe "selected_text" do
      it "1文字は有効" do
        annotation = build(:annotation, selected_text: "a")
        expect(annotation).to be_valid
      end

      it "1000文字は有効" do
        annotation = build(:annotation, selected_text: "a" * 1000)
        expect(annotation).to be_valid
      end

      it "1001文字は無効" do
        annotation = build(:annotation, selected_text: "a" * 1001)
        expect(annotation).not_to be_valid
      end

      it "空文字は無効" do
        annotation = build(:annotation, selected_text: "")
        expect(annotation).not_to be_valid
      end
    end

    describe "body" do
      it "1文字は有効" do
        annotation = build(:annotation, body: "a")
        expect(annotation).to be_valid
      end

      it "1000文字は有効" do
        annotation = build(:annotation, body: "a" * 1000)
        expect(annotation).to be_valid
      end

      it "1001文字は無効" do
        annotation = build(:annotation, body: "a" * 1001)
        expect(annotation).not_to be_valid
      end

      it "空文字は無効" do
        annotation = build(:annotation, body: "")
        expect(annotation).not_to be_valid
      end
    end

    describe "visibility" do
      it "self_onlyは有効" do
        annotation = build(:annotation, visibility: :self_only)
        expect(annotation).to be_valid
      end

      it "public_visibleは有効" do
        annotation = build(:annotation, visibility: :public_visible)
        expect(annotation).to be_valid
      end

      it "不正な値は無効" do
        annotation = build(:annotation)
        expect {
          annotation.visibility = "invalid"
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe "カスタムバリデーション" do
    describe "selection_within_single_paragraph" do
      let(:user) { create(:user) }
      let(:post) { create(:post, :published, body: "第1段落です。\n\n第2段落です。") }

      context "段落内の選択" do
        it "1つの段落内のテキストは有効" do
          annotation = build(:annotation, post: post, user: user, selected_text: "第1段落です。")
          expect(annotation).to be_valid
        end
      end

      context "段落を跨ぐ選択" do
        it "\\n\\nを含むテキストは無効" do
          annotation = build(:annotation, post: post, user: user, selected_text: "第1段落です。\n\n第2段落です。")
          expect(annotation).not_to be_valid
          expect(annotation.errors[:selected_text]).to include("は段落を跨いで選択できません。1つの段落内で選択してください。")
        end
      end
    end
  end

  describe "enums" do
    it { should define_enum_for(:visibility).with_values(self_only: "self_only", public_visible: "public").with_prefix(true).backed_by_column_of_type(:string) }
  end

  describe "インスタンスメソッド" do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }
    let(:post) { create(:post, :published) }

    describe "#marker_color_class" do
      it "自分用付箋はbg-blue-100を返す" do
        annotation = create(:annotation, post: post, user: user, visibility: :self_only)
        expect(annotation.marker_color_class).to eq("bg-blue-100")
      end

      it "公開付箋はbg-yellow-100を返す" do
        annotation = create(:annotation, post: post, user: user, visibility: :public_visible)
        expect(annotation.marker_color_class).to eq("bg-yellow-100")
      end
    end

    describe "#icon" do
      it "自分用付箋は🔒を返す" do
        annotation = create(:annotation, post: post, user: user, visibility: :self_only)
        expect(annotation.icon).to eq("🔒")
      end

      it "公開付箋は🌐を返す" do
        annotation = create(:annotation, post: post, user: user, visibility: :public_visible)
        expect(annotation.icon).to eq("🌐")
      end
    end

    describe "#invalidated?" do
      it "invalidated_atがあればtrueを返す" do
        annotation = create(:annotation, post: post, user: user, invalidated_at: 1.hour.ago)
        expect(annotation.invalidated?).to be true
      end

      it "invalidated_atがなければfalseを返す" do
        annotation = create(:annotation, post: post, user: user, invalidated_at: nil)
        expect(annotation.invalidated?).to be false
      end
    end

    describe "#active?" do
      it "invalidated_atがなければtrueを返す" do
        annotation = create(:annotation, post: post, user: user, invalidated_at: nil)
        expect(annotation.active?).to be true
      end

      it "invalidated_atがあればfalseを返す" do
        annotation = create(:annotation, post: post, user: user, invalidated_at: 1.hour.ago)
        expect(annotation.active?).to be false
      end
    end

    describe "#user_display_name" do
      it "ユーザーの表示名を返す" do
        annotation = create(:annotation, post: post, user: user)
        expect(annotation.user_display_name).to eq(user.display_name)
      end
    end
  end
end
