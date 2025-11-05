class CreateTutorDailyAggregates < ActiveRecord::Migration[8.0]
  def change
    create_table :tutor_daily_aggregates do |t|
      t.references :tutor, null: false, foreign_key: true
      t.date :date, null: false
      t.integer :sessions_completed, default: 0
      t.integer :reschedules_tutor_initiated, default: 0
      t.integer :no_shows, default: 0
      t.decimal :avg_lateness_min, precision: 10, scale: 2, default: 0.0

      t.timestamps
    end

    add_index :tutor_daily_aggregates, [:tutor_id, :date], unique: true
  end
end
