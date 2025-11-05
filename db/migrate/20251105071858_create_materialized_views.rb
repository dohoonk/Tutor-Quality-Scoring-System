class CreateMaterializedViews < ActiveRecord::Migration[8.0]
  def up
    # Create tutor_stats_7d materialized view for THS calculation
    execute <<-SQL
      CREATE MATERIALIZED VIEW tutor_stats_7d AS
      SELECT
        tutor_id,
        SUM(sessions_completed) AS sessions_completed_7d,
        SUM(reschedules_tutor_initiated) AS reschedules_tutor_initiated_7d,
        SUM(no_shows) AS no_shows_7d,
        COALESCE(AVG(avg_lateness_min), 0) AS avg_lateness_min_7d
      FROM tutor_daily_aggregates
      WHERE date >= CURRENT_DATE - INTERVAL '7 days'
      GROUP BY tutor_id;
    SQL

    # Create index on tutor_id for tutor_stats_7d
    add_index :tutor_stats_7d, :tutor_id, unique: true

    # Create tutor_stats_14d materialized view for TCRS calculation
    execute <<-SQL
      CREATE MATERIALIZED VIEW tutor_stats_14d AS
      SELECT
        tda.tutor_id,
        SUM(tda.sessions_completed) AS sessions_completed_14d,
        COUNT(DISTINCT tda.date) AS availability_14d,
        COALESCE(
          (SELECT COUNT(DISTINCT s.student_id)::decimal / NULLIF(COUNT(DISTINCT s.id), 0)
           FROM sessions s
           WHERE s.tutor_id = tda.tutor_id
             AND s.status = 'completed'
             AND s.actual_start_at >= CURRENT_DATE - INTERVAL '14 days'),
          0
        ) AS repeat_student_rate_14d
      FROM tutor_daily_aggregates tda
      WHERE tda.date >= CURRENT_DATE - INTERVAL '14 days'
      GROUP BY tda.tutor_id;
    SQL

    # Create index on tutor_id for tutor_stats_14d
    add_index :tutor_stats_14d, :tutor_id, unique: true
  end

  def down
    remove_index :tutor_stats_14d, :tutor_id if index_exists?(:tutor_stats_14d, :tutor_id)
    remove_index :tutor_stats_7d, :tutor_id if index_exists?(:tutor_stats_7d, :tutor_id)
    execute "DROP MATERIALIZED VIEW IF EXISTS tutor_stats_14d"
    execute "DROP MATERIALIZED VIEW IF EXISTS tutor_stats_7d"
  end
end
