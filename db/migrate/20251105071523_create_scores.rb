class CreateScores < ActiveRecord::Migration[8.0]
  def change
    create_table :scores do |t|
      t.references :session, null: true, foreign_key: true
      t.references :tutor, null: false, foreign_key: true
      t.string :score_type, null: false # sqs, fsrs, ths, tcrs
      t.decimal :value, precision: 10, scale: 2, null: false
      t.jsonb :components, default: {}
      t.datetime :computed_at, null: false

      t.timestamps
    end

    add_index :scores, [:tutor_id, :score_type]
    # session_id index already created by t.references
  end
end
