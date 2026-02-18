# 開発環境での OpenSSL CRL 検証エラーを回避する
# macOS の OpenSSL 3.5.x が CRL チェックに失敗する問題への対応
if Rails.env.development?
  require "openssl"

  # デフォルトの X509 証明書ストアから CRL フラグを除去する
  module OpenSSLNoCRL
    def self.store
      @store ||= begin
        store = OpenSSL::X509::Store.new
        store.set_default_paths
        store.flags = 0  # CRL チェックなし
        store
      end
    end
  end
end
