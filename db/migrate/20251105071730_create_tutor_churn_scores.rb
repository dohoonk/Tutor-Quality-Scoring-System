class CreateTutorChurnScores < ActiveRecord::Migration[8.0]
  def change
    create_table :tutor_churn_scores do |t|
      t.references :tutor, null: false, foreign_key: true
      t.decimal :tcrs_value, precision: 5, scale: 2, null: false # 0.00 to 1.00
      t.datetime :computed_at, null: false
      t.jsonb :components, default: {}

      t.timestamps
    end

    # tutor_id index already created by t.references
  end
end
