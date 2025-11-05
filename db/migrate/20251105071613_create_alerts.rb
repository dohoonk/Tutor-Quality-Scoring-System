class CreateAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :alerts do |t|
      t.references :tutor, null: false, foreign_key: true
      t.string :alert_type, null: false # poor_first_session, high_reliability_risk, churn_risk
      t.string :severity, null: false # high, medium, low
      t.string :status, null: false, default: 'open' # open, resolved, acknowledged
      t.datetime :triggered_at, null: false
      t.datetime :resolved_at, null: true
      t.jsonb :metadata, default: {}

      t.timestamps
    end
  end
end
