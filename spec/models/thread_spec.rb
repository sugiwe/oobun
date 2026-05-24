require 'rails_helper'

RSpec.describe CorrespondenceThread, type: :model do
  describe "#convert_public_annotations_to_private!" do
    let(:thread) { create(:correspondence_thread, :free) }
    let(:post1) { create(:post, :published, thread: thread) }
    let(:post2) { create(:post, :published, thread: thread) }
    let(:user) { create(:user) }

    context "公開付箋が存在する場合" do
      before do
        create(:annotation, post: post1, user: user, visibility: :public_visible)
        create(:annotation, post: post2, user: user, visibility: :public_visible)
        create(:annotation, post: post1, user: user, visibility: :self_only) # 自分用は影響なし
      end

      it "すべての公開付箋を自分用に変更する" do
        expect {
          thread.convert_public_annotations_to_private!
        }.to change {
          Annotation.joins(post: :thread).where(posts: { thread_id: thread.id }, visibility: "public").count
        }.from(2).to(0)
      end

      it "変換した付箋の数を返す" do
        count = thread.convert_public_annotations_to_private!
        expect(count).to eq(2)
      end

      it "自分用付箋は変更されない" do
        self_only_annotation = Annotation.joins(post: :thread)
                                         .where(posts: { thread_id: thread.id }, visibility: "self_only")
                                         .first

        expect {
          thread.convert_public_annotations_to_private!
        }.not_to change {
          self_only_annotation.reload.visibility
        }
      end
    end

    context "公開付箋が存在しない場合" do
      before do
        create(:annotation, post: post1, user: user, visibility: :self_only)
      end

      it "0を返す" do
        count = thread.convert_public_annotations_to_private!
        expect(count).to eq(0)
      end
    end
  end

  describe "#allow_public_annotations_changed_to_false?" do
    let(:thread) { create(:correspondence_thread, :free, allow_public_annotations: true) }

    context "true → false に変更される場合" do
      it "trueを返す（boolean）" do
        expect(thread.allow_public_annotations_changed_to_false?(false)).to be true
      end

      it "trueを返す（文字列 'false'）" do
        expect(thread.allow_public_annotations_changed_to_false?("false")).to be true
      end

      it "trueを返す（文字列 '0'）" do
        expect(thread.allow_public_annotations_changed_to_false?("0")).to be true
      end
    end

    context "true → true のまま" do
      it "falseを返す（boolean）" do
        expect(thread.allow_public_annotations_changed_to_false?(true)).to be false
      end

      it "falseを返す（文字列 'true'）" do
        expect(thread.allow_public_annotations_changed_to_false?("true")).to be false
      end

      it "falseを返す（文字列 '1'）" do
        expect(thread.allow_public_annotations_changed_to_false?("1")).to be false
      end
    end

    context "false → false のまま" do
      before { thread.update!(allow_public_annotations: false) }

      it "falseを返す" do
        expect(thread.allow_public_annotations_changed_to_false?(false)).to be false
      end
    end

    context "false → true に変更される場合" do
      before { thread.update!(allow_public_annotations: false) }

      it "falseを返す" do
        expect(thread.allow_public_annotations_changed_to_false?(true)).to be false
      end
    end
  end
end
