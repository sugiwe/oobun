class Threads::MembershipsController < ApplicationController
  before_action :require_login
  before_action :set_thread
  before_action :require_member

  # DELETE /:slug/membership - 自分が抜ける
  def destroy
    @membership = @thread.memberships.find_by!(user: current_user)

    # 最後の1人の場合は抜けられない
    # TODO: 将来的に同時アクセスが増えた場合、競合状態対策としてトランザクション内でlockを検討
    if @thread.memberships.count == 1
      redirect_to thread_path(@thread.slug), alert: "最後のメンバーは抜けることができません。交換日記を削除する場合は削除ボタンをご利用ください。"
      return
    end

    ActiveRecord::Base.transaction do
      # 下書きがある場合は削除
      draft = @thread.draft_for(current_user)
      draft&.destroy

      # メンバーシップを削除
      @membership.destroy!

      # ターン順の位置を詰める（削除されたメンバーより後ろの position を -1）
      @thread.memberships.where("position > ?", @membership.position).update_all("position = position - 1")

      # 最終投稿メタデータを更新
      @thread.update_last_post_metadata!
    end

    redirect_to root_path, notice: "「#{@thread.title}」から抜けました"
  end

  # DELETE /:slug/membership/:user_id - 他のメンバーを除外（退会済みユーザーのみ）
  def remove_member
    target_user = User.find(params[:user_id])
    target_membership = @thread.memberships.find_by!(user: target_user)

    # 退会済みユーザーのみ除外可能
    unless target_user.deleted?
      redirect_to thread_path(@thread.slug), alert: "退会済みユーザーのみ除外できます"
      return
    end

    ActiveRecord::Base.transaction do
      # メンバーシップを削除
      target_membership.destroy!

      # ターン順の位置を詰める
      @thread.memberships.where("position > ?", target_membership.position).update_all("position = position - 1")

      # 最終投稿メタデータを更新
      @thread.update_last_post_metadata!
    end

    redirect_to thread_path(@thread.slug), notice: "退会済みユーザーを除外しました"
  end

  private

  def set_thread
    @thread = CorrespondenceThread.find_by!(slug: params[:thread_slug])
  end

  def require_member
    unless @thread.member?(current_user)
      redirect_to root_path, alert: "この交換日記のメンバーではありません"
    end
  end
end
