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

ActiveRecord::Schema[8.0].define(version: 2025_11_05_072137) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "alerts", force: :cascade do |t|
    t.bigint "tutor_id", null: false
    t.string "alert_type", null: false
    t.string "severity", null: false
    t.string "status", default: "open", null: false
    t.datetime "triggered_at", null: false
    t.datetime "resolved_at"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tutor_id"], name: "index_alerts_on_tutor_id"
  end

  create_table "scores", force: :cascade do |t|
    t.bigint "session_id"
    t.bigint "tutor_id", null: false
    t.string "score_type", null: false
    t.decimal "value", precision: 10, scale: 2, null: false
    t.jsonb "components", default: {}
    t.datetime "computed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_scores_on_session_id"
    t.index ["tutor_id", "score_type"], name: "index_scores_on_tutor_id_and_score_type"
    t.index ["tutor_id"], name: "index_scores_on_tutor_id"
  end

  create_table "session_transcripts", force: :cascade do |t|
    t.bigint "session_id", null: false
    t.jsonb "payload"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_session_transcripts_on_session_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "tutor_id", null: false
    t.bigint "student_id", null: false
    t.datetime "scheduled_start_at"
    t.datetime "actual_start_at"
    t.datetime "scheduled_end_at"
    t.datetime "actual_end_at"
    t.string "status"
    t.string "reschedule_initiator"
    t.boolean "tech_issue"
    t.boolean "first_session_for_student"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["student_id"], name: "index_sessions_on_student_id"
    t.index ["tutor_id", "student_id"], name: "index_sessions_on_tutor_id_and_student_id"
    t.index ["tutor_id"], name: "index_sessions_on_tutor_id"
  end

  create_table "students", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tutor_churn_scores", force: :cascade do |t|
    t.bigint "tutor_id", null: false
    t.decimal "tcrs_value", precision: 5, scale: 2, null: false
    t.datetime "computed_at", null: false
    t.jsonb "components", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tutor_id"], name: "index_tutor_churn_scores_on_tutor_id"
  end

  create_table "tutor_daily_aggregates", force: :cascade do |t|
    t.bigint "tutor_id", null: false
    t.date "date", null: false
    t.integer "sessions_completed", default: 0
    t.integer "reschedules_tutor_initiated", default: 0
    t.integer "no_shows", default: 0
    t.decimal "avg_lateness_min", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tutor_id", "date"], name: "index_tutor_daily_aggregates_on_tutor_id_and_date", unique: true
    t.index ["tutor_id"], name: "index_tutor_daily_aggregates_on_tutor_id"
  end

  create_table "tutors", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "alerts", "tutors"
  add_foreign_key "scores", "sessions"
  add_foreign_key "scores", "tutors"
  add_foreign_key "session_transcripts", "sessions"
  add_foreign_key "sessions", "students"
  add_foreign_key "sessions", "tutors"
  add_foreign_key "tutor_churn_scores", "tutors"
  add_foreign_key "tutor_daily_aggregates", "tutors"
end
