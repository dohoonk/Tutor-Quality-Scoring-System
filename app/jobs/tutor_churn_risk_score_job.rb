class TutorChurnRiskScoreJob < ApplicationJob
  queue_as :default

  def perform
    # Calculate TCRS for all tutors based on their 14-day engagement patterns
    Tutor.find_each do |tutor|
      calculate_tcrs_for_tutor(tutor.id)
    end
  rescue StandardError => e
    Rails.logger.error "TutorChurnRiskScoreJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def calculate_tcrs_for_tutor(tutor_id)
    # Get aggregates for last 30 days (take 14 most recent)
    aggregates = TutorDailyAggregate
                 .where(tutor_id: tutor_id)
                 .where('date >= ?', 30.days.ago.to_date)
                 .order(date: :desc)
                 .limit(14) # Take only the 14 most recent days
    
    return if aggregates.empty?

    # Calculate engagement metrics
    session_counts = aggregates.map(&:sessions_completed)
    total_sessions = session_counts.sum
    avg_daily_sessions = total_sessions.to_f / aggregates.count

    # Calculate consistency (inverse of coefficient of variation)
    # Higher consistency = lower churn risk
    consistency_score = calculate_consistency(session_counts)

    # Calculate trend (improving, declining, stable)
    trend = calculate_trend(aggregates)

    # Calculate TCRS (0.0 = stable, 1.0 = high risk)
    tcrs = calculate_churn_risk(
      total_sessions: total_sessions,
      avg_daily_sessions: avg_daily_sessions,
      consistency_score: consistency_score,
      trend: trend,
      days_of_data: aggregates.count
    )

    # Store components for transparency
    components = {
      session_count: total_sessions,
      avg_daily_sessions: avg_daily_sessions.round(2),
      consistency_score: consistency_score.round(3),
      trend: trend,
      days_of_data: aggregates.count
    }

    # Check if score already exists for today
    existing_score = Score.where(
      tutor_id: tutor_id,
      score_type: 'tcrs'
    ).where('computed_at >= ?', Date.today.beginning_of_day)
     .where('computed_at <= ?', Date.today.end_of_day)
     .first

    if existing_score
      # Update existing score
      existing_score.update!(
        value: tcrs.round(3),
        components: components,
        computed_at: Time.current
      )
    else
      # Create new score
      Score.create!(
        tutor_id: tutor_id,
        session_id: nil,
        score_type: 'tcrs',
        value: tcrs.round(3),
        components: components,
        computed_at: Time.current
      )
    end
  rescue StandardError => e
    Rails.logger.error "TCRS: Failed for tutor #{tutor_id}: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
    raise
  end

  def calculate_consistency(session_counts)
    return 1.0 if session_counts.empty? || session_counts.all?(&:zero?)

    mean = session_counts.sum.to_f / session_counts.length
    return 0.0 if mean.zero?

    # Calculate standard deviation
    variance = session_counts.map { |count| (count - mean)**2 }.sum / session_counts.length
    std_dev = Math.sqrt(variance)

    # Coefficient of variation (CV) = std_dev / mean
    # Lower CV = more consistent = lower risk
    # Convert to 0-1 scale where 1 = perfect consistency, 0 = high variance
    cv = std_dev / mean
    consistency = 1.0 / (1.0 + cv) # Sigmoid-like transformation

    [0.0, [1.0, consistency].min].max # Clamp to [0, 1]
  end

  def calculate_trend(aggregates)
    return 'stable' if aggregates.count < 4

    # Split into two halves and compare averages
    sorted_by_date = aggregates.sort_by(&:date)
    mid = sorted_by_date.length / 2

    first_half = sorted_by_date[0...mid]
    second_half = sorted_by_date[mid..-1]

    first_avg = first_half.sum(&:sessions_completed).to_f / first_half.length
    second_avg = second_half.sum(&:sessions_completed).to_f / second_half.length

    difference = second_avg - first_avg

    if difference > 0.5 # Improving
      'improving'
    elsif difference < -0.5 # Declining
      'declining'
    else
      'stable'
    end
  end

  def calculate_churn_risk(total_sessions:, avg_daily_sessions:, consistency_score:, trend:, days_of_data:)
    risk = 0.0

    # Factor 1: Low activity signal (50% weight)
    # Less than 1 session/day on average = high risk
    if avg_daily_sessions < 0.5
      activity_penalty = 0.5 # Very high risk
      risk += activity_penalty
    elsif avg_daily_sessions < 1.0
      activity_penalty = (1.0 - avg_daily_sessions) * 0.5
      risk += activity_penalty
    elsif avg_daily_sessions < 2.0
      activity_penalty = (2.0 - avg_daily_sessions) / 2.0 * 0.25
      risk += activity_penalty
    end

    # Factor 2: Inconsistency signal (45% weight)
    # Low consistency = high risk
    inconsistency_penalty = (1.0 - consistency_score) * 0.45
    risk += inconsistency_penalty

    # Factor 3: Declining trend (40% weight)
    # Note: Improving bonus only applies with reasonable consistency
    case trend
    when 'declining'
      risk += 0.4
    when 'improving'
      # Only give improvement bonus if consistency is decent (> 0.5)
      # Otherwise, inconsistent improvement is too unreliable
      if consistency_score > 0.5
        improvement_bonus = 0.2 * consistency_score
        risk -= improvement_bonus
      end
    end

    # Factor 4: Insufficient data penalty (minor adjustment)
    if days_of_data < 14
      data_penalty = (14 - days_of_data) / 14.0 * 0.15
      risk += data_penalty
    end

    # Clamp to [0, 1]
    [[0.0, risk].max, 1.0].min
  end
end

