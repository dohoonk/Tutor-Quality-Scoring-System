class SessionQualityScoreService
  BASE_SCORE = 80

  def initialize(session)
    @session = session
  end

  def calculate
    lateness_penalty = calculate_lateness_penalty
    shortfall_penalty = calculate_shortfall_penalty
    tech_penalty = calculate_tech_penalty

    raw_score = BASE_SCORE - lateness_penalty - shortfall_penalty - tech_penalty
    final_score = [[raw_score, 0].max, 100].min # Clamp between 0 and 100

    label = determine_label(final_score)

    {
      score: final_score,
      label: label,
      components: {
        base: BASE_SCORE,
        lateness_penalty: lateness_penalty,
        shortfall_penalty: shortfall_penalty,
        tech_penalty: tech_penalty
      }
    }
  end

  def save_score(result)
    Score.create!(
      session: @session,
      tutor: @session.tutor,
      score_type: 'sqs',
      value: result[:score],
      components: result[:components].merge(label: result[:label]),
      computed_at: Time.current
    )
  end

  private

  def calculate_lateness_penalty
    return 0 unless @session.actual_start_at && @session.scheduled_start_at

    lateness_seconds = @session.actual_start_at - @session.scheduled_start_at
    return 0 if lateness_seconds <= 0

    lateness_minutes = (lateness_seconds / 60.0).ceil
    [20, 2 * lateness_minutes].min
  end

  def calculate_shortfall_penalty
    return 0 unless @session.actual_end_at && @session.scheduled_end_at

    shortfall_seconds = @session.scheduled_end_at - @session.actual_end_at
    return 0 if shortfall_seconds <= 0

    shortfall_minutes = (shortfall_seconds / 60.0).ceil
    [10, shortfall_minutes].min
  end

  def calculate_tech_penalty
    @session.tech_issue ? 10 : 0
  end

  def determine_label(score)
    if score < 60
      'risk'
    elsif score <= 75
      'warn'
    else
      'ok'
    end
  end
end

