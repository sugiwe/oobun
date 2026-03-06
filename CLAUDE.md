# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**重要: 日本語で返答してください。**

---

## プロジェクト概要

**coconikki** (ココニッキ) - 文通を公開するプラットフォーム
（開発コードネーム: oobun / オーブン）

2人以上のユーザーが交代で投稿を重ねていく「文通(スレッド)」を、誰でも読める形で公開するWebアプリケーション。リアルタイムチャットではなく、蓄積されていく対話を「読み物」として楽しむことに価値を置きます。

---

## 技術スタック

- Ruby on Rails 8.x (最新安定版)
- PostgreSQL
- Hotwire (Turbo + Stimulus)
- Slim テンプレート
- Google OAuth 認証

---

## 開発コマンド

```bash
# セットアップ
bin/setup

# 開発サーバー起動
bin/dev

# テスト実行
bin/rails test

# DB マイグレーション
bin/rails db:migrate

# コンソール
bin/rails console
```

---

## URL設計

- `/` - トップページ(Thread一覧)
- `/:slug` - Thread詳細
- `/:slug/:post_id` - Post詳細
- `/@username` - ユーザーページ

---

## ディレクトリ構造 (Rails規約に準拠)

```
app/
├── controllers/  # コントローラー
├── models/       # モデル (User, Thread, Post, Membership, Subscription)
├── views/        # Slimテンプレート
└── javascript/   # Stimulusコントローラー

config/
└── routes.rb     # ルーティング設定

db/
└── migrate/      # マイグレーション

docs/             # 設計ドキュメント
```

---

## 詳細ドキュメント

- [設計ドキュメント](docs/design.md) - モデル設計・ルーティング設計・交代制ロジック
- [機能仕様](docs/features.md) - 画面構成・コアコンセプト
- [実装方針](docs/implementation.md) - 制約・優先順位・Phase定義

---

## 設計方針

- **RESTful 設計**: リソースベースで表現、Rails の CRUD に沿う
- **シンプルな実装**: Rails way を最大限活用
- **拡張性を確保**: 将来の有料購読・非公開スレッドに対応可能な設計

---

## 補足

**開発コードネーム「oobun」について**: キッチン器具の「oven」ではなく、「欧文」に近い発音です。リポジトリ名やディレクトリ名は oobun のままですが、アプリケーション名は coconikki です。
