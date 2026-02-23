class SessionsController < ApplicationController
  skip_before_action :require_login, only: [ :new, :create ]
  skip_before_action :verify_authenticity_token, only: [ :create ]

  def new
    redirect_to root_path if logged_in?
  end

  def create
    # Google の CSRF トークン検証（ダブルサブミットクッキーパターン）
    unless valid_google_csrf_token?
      redirect_to login_path, alert: "不正なリクエストです"
      return
    end

    payload = verify_google_id_token(params[:credential])
    unless payload
      redirect_to login_path, alert: "Google 認証に失敗しました"
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

  private

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
    error.message.match?(/CRL|certificate revocation|revocation check/i)
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
