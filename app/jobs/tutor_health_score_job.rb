class TutorHealthScoreJob < ApplicationJob
  queue_as :default

  def perform
    # Get distinct tutor_ids from recent aggregates
    tutor_ids = TutorDailyAggregate
                .where('date >= ?', 30.days.ago.to_date)
                .distinct
                .pluck(:tutor_id)
    
    tutor_ids.each do |tutor_id|
      calculate_ths_for_tutor(tutor_id)
    end
  rescue StandardError => e
    Rails.logger.error "TutorHealthScoreJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def calculate_ths_for_tutor(tutor_id)
    # Get aggregates for last 30 days
    aggregates = TutorDailyAggregate
                 .where(tutor_id: tutor_id)
                 .where('date >= ?', 30.days.ago.to_date)
                 .order(date: :desc)
                 .take(7) # Take only the 7 most recent days (using take instead of limit to load records)
    
    return if aggregates.empty?

    # Calculate metrics
    total_sessions = aggregates.sum(:sessions_completed)
    total_reschedules = aggregates.sum(:reschedules_tutor_initiated)
    total_no_shows = aggregates.sum(:no_shows)

    # Calculate weighted average lateness (more weight on recent days)
    weighted_lateness = calculate_weighted_lateness(aggregates)

    # Calculate reschedule rate
    total_events = total_sessions + total_reschedules + total_no_shows
    reschedule_rate = total_events > 0 ? (total_reschedules.to_f / total_events) : 0.0

    # Start with perfect score
    ths = 100.0

    # Penalty for reschedule rate
    # 0% = no penalty, 10% = -5 points, 20% = -15 points, 30%+ = -25 points
    if reschedule_rate >= 0.30
      ths -= 25
    elsif reschedule_rate >= 0.20
      ths -= 15
    elsif reschedule_rate >= 0.10
      ths -= 5
    end

    # Penalty for no-shows
    # 0 = no penalty, 1-2 = -10 points, 3-5 = -20 points, 6+ = -30 points
    if total_no_shows >= 6
      ths -= 30
    elsif total_no_shows >= 3
      ths -= 20
    elsif total_no_shows >= 1
      ths -= 10
    end

    # Penalty for lateness (weighted average)
    # 0 min = no penalty, 5 min = -5 points, 10 min = -15 points, 15+ min = -25 points
    if weighted_lateness >= 15.0
      ths -= 25
    elsif weighted_lateness >= 10.0
      ths -= 15
    elsif weighted_lateness >= 5.0
      ths -= 5
    end

    # Ensure THS is between 0 and 100
    ths = [[ths, 0].max, 100].min

    # Store components
    components = {
      reschedule_rate: reschedule_rate.round(3),
      no_show_count: total_no_shows,
      avg_lateness: weighted_lateness.round(2),
      total_sessions: total_sessions,
      days_of_data: aggregates.count
    }

    # Check if we already have a THS score for today
    existing_score = Score.where(
      tutor_id: tutor_id,
      score_type: 'ths'
    ).where('computed_at >= ?', Date.today.beginning_of_day)
     .where('computed_at <= ?', Date.today.end_of_day)
     .first

    if existing_score
      # Update existing score
      existing_score.update!(
        value: ths.round(2),
        components: components,
        computed_at: Time.current
      )
    else
      # Create new score
      Score.create!(
        tutor_id: tutor_id,
        session_id: nil,
        score_type: 'ths',
        value: ths.round(2),
        components: components,
        computed_at: Time.current
      )
    end
  end

  def calculate_weighted_lateness(aggregates)
    # Give more weight to recent days (last 3 days = 60%, older 4 days = 40%)
    recent_aggregates = aggregates.first(3)
    older_aggregates = aggregates[3..-1] || []

    recent_lateness = recent_aggregates.sum(:avg_lateness_min)
    recent_days = [recent_aggregates.count, 1].max

    older_lateness = older_aggregates.sum(:avg_lateness_min)
    older_days = [older_aggregates.count, 1].max

    # Weighted average: 60% recent, 40% older
    if recent_aggregates.any? && older_aggregates.any?
      ((recent_lateness / recent_days) * 0.6) + ((older_lateness / older_days) * 0.4)
    elsif recent_aggregates.any?
      recent_lateness / recent_days
    elsif older_aggregates.any?
      older_lateness / older_days
    else
      0.0
    end
  end
end

