class Threads::MembershipsController < ApplicationController
  before_action :require_login
  before_action :set_thread
  before_action :require_member, only: [ :destroy ]
  before_action :require_admin_permission, only: [ :remove_member ]
  before_action :require_owner_permission, only: [ :promote_to_admin, :demote_to_member ]

  # DELETE /:slug/membership - 自分が抜ける
  def destroy
    @membership = @thread.memberships.find_by!(user: current_user)

    # オーナーは抜けられない
    if @membership.owner?
      redirect_to thread_path(@thread.slug), alert: "オーナーは交換日記から抜けることができません。交換日記を削除する場合は削除ボタンをご利用ください。"
      return
    end

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

  # PATCH /:slug/memberships/:user_id/promote - メンバーを管理者に昇格
  def promote_to_admin
    target_user = User.find(params[:user_id])
    target_membership = @thread.memberships.find_by!(user: target_user)

    # オーナーは昇格できない
    if target_membership.owner?
      redirect_to edit_thread_path(@thread.slug), alert: "オーナーは昇格できません"
      return
    end

    # 既に管理者の場合
    if target_membership.admin?
      redirect_to edit_thread_path(@thread.slug), alert: "既に管理者です"
      return
    end

    target_membership.update!(role: "admin")
    redirect_to edit_thread_path(@thread.slug), notice: "#{target_user.username}を管理者に昇格しました"
  end

  # PATCH /:slug/memberships/:user_id/demote - 管理者をメンバーに降格
  def demote_to_member
    target_user = User.find(params[:user_id])
    target_membership = @thread.memberships.find_by!(user: target_user)

    # オーナーは降格できない
    if target_membership.owner?
      redirect_to edit_thread_path(@thread.slug), alert: "オーナーは降格できません"
      return
    end

    # 既にメンバーの場合
    if target_membership.member?
      redirect_to edit_thread_path(@thread.slug), alert: "既にメンバーです"
      return
    end

    target_membership.update!(role: "member")
    redirect_to edit_thread_path(@thread.slug), notice: "#{target_user.username}をメンバーに降格しました"
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

  def require_admin_permission
    unless @thread.admin_by?(current_user)
      redirect_to thread_path(@thread.slug), alert: "管理者権限が必要です"
    end
  end

  def require_owner_permission
    unless @thread.owner_by?(current_user)
      redirect_to edit_thread_path(@thread.slug), alert: "オーナー権限が必要です"
    end
  end
end
