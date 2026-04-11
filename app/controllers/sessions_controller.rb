class SessionsController < ApplicationController
  skip_before_action :require_login, only: [ :new, :create, :dev_login ]

  # ログイン許可はAllowedUserテーブルで管理（招待リンク or 管理者追加）

  def new
    redirect_to root_path if logged_in?
  end

  def create
    # Google の CSRF トークン検証（ダブルサブミットクッキーパターン）
    # Rails標準のauthenticity_tokenに加えて、Googleが推奨するg_csrf_tokenも検証
    # ただし、Google Sign-In JavaScript ライブラリ使用時はg_csrf_tokenが設定されないため
    # 現時点ではRails標準のCSRF保護のみに依存
    # TODO: 将来的にサーバーサイドOAuthフローに移行時に有効化
    # if !Rails.env.development? && !valid_google_csrf_token?
    #   redirect_to login_path, alert: "不正なリクエストです"
    #   return
    # end

    payload = verify_google_id_token(params[:credential])
    unless payload
      redirect_to login_path, alert: "Google 認証に失敗しました"
      return
    end

    # 月間枠チェック（招待をキャッシュして重複クエリを防ぐ）
    invitation = cached_invitation
    user = User.find_or_initialize_from_google(payload)

    # 新規ユーザーの場合、月間枠または招待をチェック
    if user.new_record? && !signup_allowed?(invitation)
      redirect_to login_path, alert: "今月の新規登録枠が上限に達しました。来月またお試しください。"
      return
    end

    if user.new_record? || user.username.blank?
      # 新規ユーザー: username 設定画面へ
      session[:pending_google_payload] = payload.slice("sub", "email", "name", "picture")
      redirect_to new_username_path
    else
      session[:user_id] = user.id
      user.update_column(:last_sign_in_at, Time.current)
      thread_slug = process_invitation_if_present(user, invitation)
      if thread_slug
        redirect_to thread_path(thread_slug), notice: "ログインして交換日記に参加しました！"
      else
        redirect_to root_path, notice: "ログインしました"
      end
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to root_path, notice: "ログアウトしました"
  end

  # 開発環境専用：テストユーザーで即座にログイン
  def dev_login
    unless Rails.env.development?
      head :forbidden
      return
    end

    user = User.find_by(username: params[:username])
    unless user
      redirect_to login_path, alert: "テストユーザーが見つかりません"
      return
    end

    session[:user_id] = user.id
    user.update_column(:last_sign_in_at, Time.current)
    redirect_to root_path, notice: "#{user.display_name} としてログインしました"
  end

  private

  # 招待トークンをキャッシュして重複クエリを防ぐ
  def cached_invitation
    return nil unless session[:invitation_token].present?

    @cached_invitation ||= Invitation.find_by(token: session[:invitation_token])
  end

  # 新規登録許可チェック: 月間枠または招待
  def signup_allowed?(invitation = nil)
    # 交換日記への招待が有効か確認（招待経由は枠カウント外）
    return true if invitation&.usable?

    # 月間枠に空きがあるかチェック
    MonthlySignupQuota.current_month.available?
  end

  def valid_google_csrf_token?
    cookies["g_csrf_token"].present? &&
      params["g_csrf_token"].present? &&
      cookies["g_csrf_token"] == params["g_csrf_token"]
  end

  def verify_google_id_token(credential)
    Google::Auth::IDTokens.verify_oidc(credential, aud: GOOGLE_CLIENT_ID)
  rescue Google::Auth::IDTokens::VerificationError => e
    Rails.logger.warn "Google ID token verification failed: #{e.message}"
    # CRL関連エラーの場合のみ、CRLなしで再試行
    if crl_related_error?(e)
      Rails.logger.info "CRL-related error detected, retrying without CRL check"
      verify_google_id_token_without_crl(credential)
    else
      # 有効期限切れやオーディエンス不一致などの場合はnilを返す
      Rails.logger.warn "Non-CRL verification error, authentication failed"
      nil
    end
  rescue OpenSSL::SSL::SSLError => e
    # 開発環境での CRL 検証エラーを回避
    Rails.logger.warn "SSL error during Google token verification: #{e.message}"
    verify_google_id_token_without_crl(credential)
  end

  def crl_related_error?(error)
    # CRL関連のエラーメッセージパターンをチェック
    error.message.match?(/CRL|certificate revocation|revocation check|Token not verified as issued by Google/i)
  end

  def verify_google_id_token_without_crl(credential)
    # CRL チェックなしで Net::HTTP を使い JWK を直接取得して検証（開発環境用）
    # JwkHttpKeySource は Net::HTTP をハードコードしており SSL 設定を注入できないため
    # サブクラスで refresh_keys を上書きしてカスタム証明書ストアを使用する
    store = OpenSSL::X509::Store.new
    store.set_default_paths
    store.flags = 0  # CRL チェックを無効化

    jwks_uri = URI("https://www.googleapis.com/oauth2/v3/certs")
    http = Net::HTTP.new(jwks_uri.host, jwks_uri.port)
    http.use_ssl = true
    http.cert_store = store
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    response = http.get(jwks_uri.path)
    raise "JWK fetch failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    jwk_set = JSON.parse(response.body)
    key_source = Google::Auth::IDTokens::StaticKeySource.from_jwk_set(jwk_set)
    verifier = Google::Auth::IDTokens::Verifier.new(key_source: key_source)
    verifier.verify(credential, aud: GOOGLE_CLIENT_ID)
  rescue StandardError => e
    Rails.logger.warn "Token verification failed without CRL: #{e.message}"
    nil
  end
end
