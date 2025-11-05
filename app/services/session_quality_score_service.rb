class SessionQualityScoreService
  include TranscriptAnalysis

  MAX_SCORE = 100

  def initialize(session)
    @session = session
  end

  def calculate
    # Skip if transcript is missing (user requirement: skip session if no transcript)
    return nil unless transcript_present?
    return nil unless speaker_diarization_present?

    # Operational penalties (from timing/metadata)
    lateness_penalty = calculate_lateness_penalty
    shortfall_penalty = calculate_shortfall_penalty
    tech_penalty = calculate_tech_penalty

    # Transcript-based penalties (same as FSQS metrics)
    confusion_penalty = detect_confusion_phrases
    word_share_penalty = detect_word_share_imbalance
    goal_setting_penalty = detect_missing_goal_setting
    encouragement_penalty = detect_missing_encouragement
    closing_summary_penalty = detect_missing_closing_summary
    negative_phrasing_penalty = detect_negative_phrasing

    # Calculate total penalties
    operational_penalties = lateness_penalty + shortfall_penalty + tech_penalty
    transcript_penalties = confusion_penalty + word_share_penalty + goal_setting_penalty + 
                          encouragement_penalty + closing_summary_penalty + negative_phrasing_penalty
    total_penalties = operational_penalties + transcript_penalties

    # SQS: Start at 100 (perfect) and subtract penalties (higher is better)
    raw_score = MAX_SCORE - total_penalties
    final_score = [[raw_score, 0].max, 100].min # Clamp between 0 and 100

    label = determine_label(final_score)

    {
      score: final_score,
      label: label,
      components: {
        # Operational components
        lateness_penalty: lateness_penalty,
        shortfall_penalty: shortfall_penalty,
        tech_penalty: tech_penalty,
        # Transcript components
        confusion_phrases: confusion_penalty,
        word_share_imbalance: word_share_penalty,
        missing_goal_setting: goal_setting_penalty,
        missing_encouragement: encouragement_penalty,
        missing_closing_summary: closing_summary_penalty,
        negative_phrasing: negative_phrasing_penalty
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

