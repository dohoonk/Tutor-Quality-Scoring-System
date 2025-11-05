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

ActiveRecord::Schema[8.0].define(version: 2025_11_05_071010) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "tutors", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "sessions", "students"
  add_foreign_key "sessions", "tutors"
end
