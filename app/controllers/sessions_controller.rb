class SessionsController < ApplicationController
  skip_before_action :require_login, only: [ :new, :create, :dev_login ]

  # ベータ版：ログイン許可メールアドレスリスト（起動時に一度だけ読み込み）
  ALLOWED_EMAILS_SET =
    if ENV["ALLOWED_EMAILS"].present?
      ENV["ALLOWED_EMAILS"].split(",").map(&:strip).to_set
    end
  private_constant :ALLOWED_EMAILS_SET

  def new
    redirect_to root_path if logged_in?
  end

  def create
    # Google の CSRF トークン検証（ダブルサブミットクッキーパターン）
    # Rails標準のauthenticity_tokenに加えて、Googleが推奨するg_csrf_tokenも検証
    # ただし、g_csrf_tokenは本番環境でのみGoogleが設定するため、開発環境ではスキップ
    if !Rails.env.development? && !valid_google_csrf_token?
      redirect_to login_path, alert: "不正なリクエストです"
      return
    end

    payload = verify_google_id_token(params[:credential])
    unless payload
      redirect_to login_path, alert: "Google 認証に失敗しました"
      return
    end

    # ベータ版：メールアドレス許可リストチェック（開発環境ではスキップ）
    unless Rails.env.development? || email_allowed?(payload["email"])
      redirect_to login_path, alert: "現在ベータ版のため、招待されたユーザーのみログインできます。"
      return
    end

    user = User.find_or_initialize_from_google(payload)

    if user.new_record? || user.username.blank?
      # 新規ユーザー: username 設定画面へ
      session[:pending_google_payload] = payload.slice("sub", "email", "name", "picture")
      redirect_to new_username_path
    else
      session[:user_id] = user.id
      redirect_to root_path, notice: "ログインしました"
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
    redirect_to root_path, notice: "#{user.display_name} としてログインしました"
  end

  private

  def email_allowed?(email)
    # ALLOWED_EMAILS_SET が未設定の場合は全て許可
    return true if ALLOWED_EMAILS_SET.nil?

    # Set の include? は O(1) で高速
    ALLOWED_EMAILS_SET.include?(email)
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
