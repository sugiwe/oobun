# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_14_202126) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "allowed_users", force: :cascade do |t|
    t.boolean "added_by_admin", default: false, null: false
    t.boolean "contacted", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.bigint "invited_by_id"
    t.text "note"
    t.datetime "updated_at", null: false
    t.index ["added_by_admin"], name: "index_allowed_users_on_added_by_admin"
    t.index ["contacted"], name: "index_allowed_users_on_contacted"
    t.index ["email"], name: "index_allowed_users_on_email", unique: true
    t.index ["invited_by_id"], name: "index_allowed_users_on_invited_by_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "invited_by_id", null: false
    t.bigint "thread_id", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["thread_id"], name: "index_invitations_on_thread_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position", null: false
    t.string "role", default: "writer", null: false
    t.bigint "thread_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["thread_id", "position"], name: "index_memberships_on_thread_id_and_position", unique: true
    t.index ["thread_id"], name: "index_memberships_on_thread_id"
    t.index ["user_id", "thread_id"], name: "index_memberships_on_user_id_and_thread_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "posts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "published_at"
    t.string "status", default: "published", null: false
    t.bigint "thread_id", null: false
    t.string "title", default: "", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["published_at"], name: "index_posts_on_published_at"
    t.index ["status"], name: "index_posts_on_status"
    t.index ["thread_id", "created_at"], name: "index_posts_on_thread_id_and_created_at"
    t.index ["thread_id", "status"], name: "index_posts_on_thread_id_and_status"
    t.index ["thread_id"], name: "index_posts_on_thread_id"
    t.index ["user_id", "thread_id"], name: "index_posts_on_user_thread_draft_uniqueness", unique: true, where: "((status)::text = 'draft'::text)"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "skips", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "thread_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["thread_id", "created_at"], name: "index_skips_on_thread_id_and_created_at"
    t.index ["thread_id"], name: "index_skips_on_thread_id"
    t.index ["user_id"], name: "index_skips_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "thread_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["thread_id"], name: "index_subscriptions_on_thread_id"
    t.index ["user_id", "thread_id"], name: "index_subscriptions_on_user_id_and_thread_id", unique: true
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "threads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "is_sample", default: false, null: false
    t.integer "last_post_user_id"
    t.datetime "last_posted_at"
    t.boolean "show_in_list", default: false, null: false
    t.string "slug", null: false
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.boolean "turn_based", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["is_sample"], name: "index_threads_on_is_sample"
    t.index ["last_posted_at"], name: "index_threads_on_last_posted_at"
    t.index ["slug"], name: "index_threads_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.text "bio"
    t.datetime "created_at", null: false
    t.string "display_name", null: false
    t.string "email", null: false
    t.string "google_uid"
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["google_uid"], name: "index_users_on_google_uid", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "allowed_users", "users", column: "invited_by_id"
  add_foreign_key "invitations", "threads"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "memberships", "threads"
  add_foreign_key "memberships", "users"
  add_foreign_key "posts", "threads"
  add_foreign_key "posts", "users"
  add_foreign_key "skips", "threads"
  add_foreign_key "skips", "users"
  add_foreign_key "subscriptions", "threads"
  add_foreign_key "subscriptions", "users"
end
