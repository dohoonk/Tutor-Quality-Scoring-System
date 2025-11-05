class CreateSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :sessions do |t|
      t.references :tutor, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: true
      t.datetime :scheduled_start_at
      t.datetime :actual_start_at
      t.datetime :scheduled_end_at
      t.datetime :actual_end_at
      t.string :status
      t.string :reschedule_initiator
      t.boolean :tech_issue
      t.boolean :first_session_for_student

      t.timestamps
    end

    # Composite index for tutor-student pair lookups
    add_index :sessions, [:tutor_id, :student_id]
  end
end
