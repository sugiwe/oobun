require "rails_helper"

RSpec.describe "Threads::Posts::AnnotationsController", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:correspondence_thread) { create(:correspondence_thread, :free) }
  let(:published_post) { create(:post, status: :published, thread: correspondence_thread, user: user) }

  # Request specでのログインヘルパー
  def sign_in_user(user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)
  end

  describe "POST /threads/:thread_slug/posts/:post_id/annotations" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        post thread_post_annotations_path(thread_slug: correspondence_thread.slug, post_id: published_post.slug),
             params: { annotation: { selected_text: "test", body: "test", visibility: "self_only" } }
        expect(response).to have_http_status(:redirect)
      end
    end

    context "ログイン済みの場合" do
      before { sign_in_user other_user }

      context "公開投稿に付箋を付ける" do
        it "付箋が作成される" do
          expect {
            post thread_post_annotations_path(thread_slug: correspondence_thread.slug, post_id: published_post.slug),
                 params: { annotation: { selected_text: "test text", body: "test body", visibility: "self_only", paragraph_index: 0 } },
                 headers: { "Accept" => "application/json" }
          }.to change { published_post.annotations.count }.by(1)

          expect(response).to have_http_status(:created)
          json = JSON.parse(response.body)
          expect(json["success"]).to be true
        end
      end

      context "他人の下書きに付箋を付けようとした場合" do
        let(:draft_post) { create(:post, status: :draft, title: "Draft Title", body: "Draft body", thread: correspondence_thread, user: user) }

        it "403を返す" do
          post thread_post_annotations_path(thread_slug: correspondence_thread.slug, post_id: draft_post.id),
               params: { annotation: { selected_text: "test", body: "test", visibility: "self_only", paragraph_index: 0 } },
               headers: { "Accept" => "application/json" }

          expect(response).to have_http_status(:forbidden)
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["message"]).to eq "この投稿には付箋を追加できません"
        end
      end

      context "自分の下書きに付箋を付ける場合" do
        let(:my_draft) { create(:post, status: :draft, title: "My Draft", body: "My draft body", thread: correspondence_thread, user: other_user) }

        it "付箋が作成される" do
          expect {
            post thread_post_annotations_path(thread_slug: correspondence_thread.slug, post_id: my_draft.id),
                 params: { annotation: { selected_text: "test text", body: "test body", visibility: "self_only", paragraph_index: 0 } },
                 headers: { "Accept" => "application/json" }
          }.to change { my_draft.annotations.count }.by(1)

          expect(response).to have_http_status(:created)
        end
      end
    end
  end

  describe "PATCH /threads/:thread_slug/posts/:post_id/annotations/:id" do
    let!(:annotation) { create(:annotation, post: published_post, user: other_user) }

    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        patch thread_post_annotation_path(thread_slug: correspondence_thread.slug, post_id: published_post.slug, id: annotation.id),
              params: { annotation: { body: "updated" } }
        expect(response).to have_http_status(:redirect)
      end
    end

    context "付箋の所有者の場合" do
      before { sign_in_user other_user }

      it "付箋を更新できる" do
        patch thread_post_annotation_path(thread_slug: correspondence_thread.slug, post_id: published_post.slug, id: annotation.id),
              params: { annotation: { body: "updated body" } },
              headers: { "Accept" => "application/json" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(annotation.reload.body).to eq "updated body"
      end
    end

    context "他人の付箋を更新しようとした場合" do
      before { sign_in_user user }

      it "403を返す" do
        patch thread_post_annotation_path(thread_slug: correspondence_thread.slug, post_id: published_post.slug, id: annotation.id),
              params: { annotation: { body: "hacked" } },
              headers: { "Accept" => "application/json" }

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json["success"]).to be false
        expect(annotation.reload.body).not_to eq "hacked"
      end
    end
  end

  describe "DELETE /threads/:thread_slug/posts/:post_id/annotations/:id" do
    let!(:annotation) { create(:annotation, post: published_post, user: other_user) }

    context "未ログインの場合" do
      it "ログインページにリダイレクトされる" do
        delete thread_post_annotation_path(thread_slug: correspondence_thread.slug, post_id: published_post.slug, id: annotation.id)
        expect(response).to have_http_status(:redirect)
      end
    end

    context "付箋の所有者の場合" do
      before { sign_in_user other_user }

      it "付箋を削除できる" do
        expect {
          delete thread_post_annotation_path(thread_slug: correspondence_thread.slug, post_id: published_post.slug, id: annotation.id),
                 headers: { "Accept" => "application/json" }
        }.to change { published_post.annotations.count }.by(-1)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end
    end

    context "他人の付箋を削除しようとした場合" do
      before { sign_in_user user }

      it "403を返す" do
        expect {
          delete thread_post_annotation_path(thread_slug: correspondence_thread.slug, post_id: published_post.slug, id: annotation.id),
                 headers: { "Accept" => "application/json" }
        }.not_to change { published_post.annotations.count }

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json["success"]).to be false
      end
    end
  end
end
