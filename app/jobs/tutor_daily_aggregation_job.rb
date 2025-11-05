class TutorDailyAggregationJob < ApplicationJob
  queue_as :default

  def perform
    # Find all sessions from the last 30 days to ensure we catch any late data
    start_date = 30.days.ago.to_date
    end_date = Date.today

    # Group sessions by tutor and date
    sessions_by_tutor_and_date = Session.where('scheduled_start_at >= ?', start_date.beginning_of_day)
                                         .where('scheduled_start_at <= ?', end_date.end_of_day)
                                         .group_by { |session| [session.tutor_id, session.scheduled_start_at.to_date] }

    sessions_by_tutor_and_date.each do |(tutor_id, date), sessions|
      aggregate_for_tutor_and_date(tutor_id, date, sessions)
    end

    # Refresh materialized view after aggregation
    refresh_materialized_views
  rescue StandardError => e
    Rails.logger.error "TutorDailyAggregationJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def aggregate_for_tutor_and_date(tutor_id, date, sessions)
    # Calculate metrics
    completed_sessions = sessions.select { |s| s.status == 'completed' }
    reschedules_tutor = sessions.count { |s| s.status == 'rescheduled' && s.reschedule_initiator == 'tutor' }
    no_shows = sessions.count { |s| s.status == 'no_show' }

    # Calculate average lateness for completed sessions
    lateness_values = completed_sessions.map do |session|
      if session.actual_start_at && session.scheduled_start_at
        ((session.actual_start_at - session.scheduled_start_at) / 60.0).round(2)
      else
        0.0
      end
    end.select { |lateness| lateness > 0 } # Only positive lateness

    avg_lateness = lateness_values.any? ? (lateness_values.sum / lateness_values.length).round(2) : 0.0

    # Find or create the aggregate record
    aggregate = TutorDailyAggregate.find_or_initialize_by(
      tutor_id: tutor_id,
      date: date
    )

    aggregate.update!(
      sessions_completed: completed_sessions.count,
      reschedules_tutor_initiated: reschedules_tutor,
      no_shows: no_shows,
      avg_lateness_min: avg_lateness
    )
  end

  def refresh_materialized_views
    # Check if materialized views exist before trying to refresh them
    views_exist = ActiveRecord::Base.connection.execute(
      "SELECT matviewname FROM pg_matviews WHERE matviewname IN ('tutor_stats_7d', 'tutor_stats_14d')"
    ).count == 2

    return unless views_exist

    # Refresh the 7-day and 14-day materialized views
    begin
      ActiveRecord::Base.connection.execute('REFRESH MATERIALIZED VIEW CONCURRENTLY tutor_stats_7d;')
      ActiveRecord::Base.connection.execute('REFRESH MATERIALIZED VIEW CONCURRENTLY tutor_stats_14d;')
      Rails.logger.info "Refreshed materialized views: tutor_stats_7d, tutor_stats_14d"
    rescue ActiveRecord::StatementInvalid => e
      # If CONCURRENTLY fails (e.g., no unique index), fall back to regular refresh
      Rails.logger.warn "Concurrent refresh failed, using regular refresh: #{e.message}"
      begin
        ActiveRecord::Base.connection.execute('REFRESH MATERIALIZED VIEW tutor_stats_7d;')
        ActiveRecord::Base.connection.execute('REFRESH MATERIALIZED VIEW tutor_stats_14d;')
        Rails.logger.info "Refreshed materialized views (non-concurrent): tutor_stats_7d, tutor_stats_14d"
      rescue ActiveRecord::StatementInvalid => refresh_error
        Rails.logger.error "Failed to refresh materialized views: #{refresh_error.message}"
      end
    end
  end
end

