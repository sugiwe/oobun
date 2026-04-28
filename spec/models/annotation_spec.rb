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

    describe "paragraph_index_within_range" do
      let(:user) { create(:user) }

      context "空行で区切られた段落" do
        let(:post) { create(:post, :published, body: "第1段落\n\n第2段落\n\n第3段落") }

        it "範囲内のインデックスは有効（index=0）" do
          annotation = build(:annotation, post: post, user: user, paragraph_index: 0, selected_text: "第1段落")
          expect(annotation).to be_valid
        end

        it "範囲内のインデックスは有効（index=2）" do
          annotation = build(:annotation, post: post, user: user, paragraph_index: 2, selected_text: "第3段落")
          expect(annotation).to be_valid
        end

        it "範囲外のインデックスは無効（index=3）" do
          annotation = build(:annotation, post: post, user: user, paragraph_index: 3, selected_text: "test")
          expect(annotation).not_to be_valid
          expect(annotation.errors[:paragraph_index]).to include("が投稿の段落数を超えています")
        end
      end

      context "見出しと本文（空行なし）" do
        let(:post) { create(:post, :published, body: "# 見出し\n本文テキスト") }

        it "見出し（index=0）は有効" do
          annotation = build(:annotation, post: post, user: user, paragraph_index: 0, selected_text: "見出し")
          expect(annotation).to be_valid
        end

        it "本文（index=1）は有効" do
          annotation = build(:annotation, post: post, user: user, paragraph_index: 1, selected_text: "本文テキスト")
          expect(annotation).to be_valid
        end

        it "範囲外（index=2）は無効" do
          annotation = build(:annotation, post: post, user: user, paragraph_index: 2, selected_text: "test")
          expect(annotation).not_to be_valid
          expect(annotation.errors[:paragraph_index]).to include("が投稿の段落数を超えています")
        end
      end

      context "複数の見出しとリスト" do
        let(:post) do
          create(:post, :published, body: <<~MD)
            # タイトル
            本文です。

            ## 小見出し
            - リスト1
            - リスト2

            最後の段落
          MD
        end

        # 期待されるブロック: h1, p, h2, ul, p = 5個
        it "範囲内のインデックスは有効（index=4）" do
          annotation = build(:annotation, post: post, user: user, paragraph_index: 4, selected_text: "最後の段落")
          expect(annotation).to be_valid
        end

        it "範囲外のインデックスは無効（index=5）" do
          annotation = build(:annotation, post: post, user: user, paragraph_index: 5, selected_text: "test")
          expect(annotation).not_to be_valid
          expect(annotation.errors[:paragraph_index]).to include("が投稿の段落数を超えています")
        end
      end

      context "ネストしたリスト" do
        let(:post) do
          create(:post, :published, body: <<~MD)
            - トップレベル1
              - ネスト1
              - ネスト2
            - トップレベル2
          MD
        end

        # 期待されるブロック: ul（最上位のみ）= 1個
        it "範囲内のインデックスは有効（index=0）" do
          annotation = build(:annotation, post: post, user: user, paragraph_index: 0, selected_text: "トップレベル1")
          expect(annotation).to be_valid
        end

        it "範囲外のインデックスは無効（index=1）" do
          annotation = build(:annotation, post: post, user: user, paragraph_index: 1, selected_text: "test")
          expect(annotation).not_to be_valid
          expect(annotation.errors[:paragraph_index]).to include("が投稿の段落数を超えています")
        end
      end

      context "paragraph_indexがnilの場合" do
        let(:post) { create(:post, :published, body: "テストの本文です。10文字以上必要。") }

        it "バリデーションをスキップする" do
          annotation = build(:annotation, post: post, user: user, paragraph_index: nil, selected_text: "テストの本文です")
          expect(annotation).to be_valid
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

    describe "#visible_to?" do
      context "公開付箋の場合" do
        let(:public_annotation) { create(:annotation, post: post, user: user, visibility: :public_visible) }

        it "ゲストユーザー（nil）にはtrueを返す" do
          expect(public_annotation.visible_to?(nil)).to be true
        end

        it "作成者にはtrueを返す" do
          expect(public_annotation.visible_to?(user)).to be true
        end

        it "他のユーザーにはtrueを返す" do
          expect(public_annotation.visible_to?(other_user)).to be true
        end
      end

      context "自分用付箋の場合" do
        let(:private_annotation) { create(:annotation, post: post, user: user, visibility: :self_only) }

        it "ゲストユーザー（nil）にはfalseを返す" do
          expect(private_annotation.visible_to?(nil)).to be false
        end

        it "作成者にはtrueを返す" do
          expect(private_annotation.visible_to?(user)).to be true
        end

        it "他のユーザーにはfalseを返す" do
          expect(private_annotation.visible_to?(other_user)).to be false
        end
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
