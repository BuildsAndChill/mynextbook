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

ActiveRecord::Schema[8.0].define(version: 2025_08_20_112903) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "book_metadata", force: :cascade do |t|
    t.string "title", null: false
    t.string "author", null: false
    t.string "isbn"
    t.string "isbn13"
    t.bigint "goodreads_book_id"
    t.decimal "average_rating", precision: 4, scale: 2
    t.integer "pages"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["goodreads_book_id"], name: "index_book_metadata_on_goodreads_book_id", unique: true, where: "(goodreads_book_id IS NOT NULL)"
    t.index ["isbn"], name: "index_book_metadata_on_isbn", unique: true, where: "(isbn IS NOT NULL)"
    t.index ["isbn13"], name: "index_book_metadata_on_isbn13", unique: true, where: "(isbn13 IS NOT NULL)"
    t.index ["title", "author"], name: "index_book_metadata_on_title_and_author", unique: true, where: "((isbn IS NULL) AND (isbn13 IS NULL) AND (goodreads_book_id IS NULL))"
  end

  create_table "interactions", force: :cascade do |t|
    t.bigint "user_session_id", null: false
    t.string "action_type"
    t.json "action_data"
    t.string "context"
    t.json "metadata"
    t.datetime "timestamp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_session_id"], name: "index_interactions_on_user_session_id"
  end

  create_table "subscriber_interactions", force: :cascade do |t|
    t.bigint "subscriber_id", null: false
    t.string "context"
    t.text "tone_chips"
    t.text "ai_response"
    t.text "parsed_response"
    t.string "session_id"
    t.integer "interaction_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["subscriber_id"], name: "index_subscriber_interactions_on_subscriber_id"
  end

  create_table "subscribers", force: :cascade do |t|
    t.string "email"
    t.text "context"
    t.text "tone_chips"
    t.text "ai_response"
    t.text "parsed_response"
    t.integer "interaction_count"
    t.string "session_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_subscribers_on_email"
  end

  create_table "user_book_feedbacks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "book_title"
    t.string "book_author"
    t.integer "feedback_type"
    t.text "recommendation_context"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_book_feedbacks_on_user_id"
  end

  create_table "user_readings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "book_metadata_id", null: false
    t.integer "rating"
    t.string "status", default: "to_read", null: false
    t.text "shelves"
    t.date "date_added"
    t.date "date_read"
    t.string "exclusive_shelf"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_metadata_id"], name: "index_user_readings_on_book_metadata_id"
    t.index ["status"], name: "index_user_readings_on_status"
    t.index ["user_id", "book_metadata_id"], name: "index_user_readings_on_user_id_and_book_metadata_id", unique: true
    t.index ["user_id"], name: "index_user_readings_on_user_id"
  end

  create_table "user_sessions", force: :cascade do |t|
    t.string "session_identifier"
    t.text "device_info"
    t.text "user_agent"
    t.string "ip_address"
    t.datetime "last_activity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "interactions", "user_sessions"
  add_foreign_key "subscriber_interactions", "subscribers"
  add_foreign_key "user_book_feedbacks", "users"
  add_foreign_key "user_readings", "book_metadata", column: "book_metadata_id"
  add_foreign_key "user_readings", "users"
end
