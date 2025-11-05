# frozen_string_literal: true

class SessionScoringJob < ApplicationJob
  queue_as :default

  def perform
    # Find completed sessions without SQS scores
    sessions_without_sqs = Session
      .where(status: 'completed')
      .left_joins(:scores)
      .where('scores.id IS NULL OR scores.score_type != ?', 'sqs')
      .group('sessions.id')
      .having('COUNT(CASE WHEN scores.score_type = ? THEN 1 END) = 0', 'sqs')

    sessions_without_sqs.find_each do |session|
      compute_sqs(session)
    end

    # Find first sessions with transcripts without FSRS scores
    first_sessions_without_fsrs = Session
      .where(status: 'completed', first_session_for_student: true)
      .joins(:session_transcript)
      .left_joins(:scores)
      .group('sessions.id')
      .having('COUNT(CASE WHEN scores.score_type = ? THEN 1 END) = 0', 'fsrs')

    first_sessions_without_fsrs.find_each do |session|
      compute_fsrs(session)
    end
  end

  private

  def compute_sqs(session)
    return unless session.actual_start_at && session.actual_end_at

    sqs = 100.0
    components = {}

    # Calculate lateness penalty
    if session.scheduled_start_at
      lateness_minutes = ((session.actual_start_at - session.scheduled_start_at) / 60.0).round
      if lateness_minutes > 0
        lateness_penalty = [lateness_minutes * 2, 30].min # Max 30 point penalty
        sqs -= lateness_penalty
        components['lateness_penalty'] = lateness_penalty
        components['lateness_minutes'] = lateness_minutes
      end
    end

    # Calculate duration shortfall penalty
    if session.scheduled_end_at
      scheduled_duration = (session.scheduled_end_at - session.scheduled_start_at) / 60.0
      actual_duration = (session.actual_end_at - session.actual_start_at) / 60.0
      duration_shortfall = scheduled_duration - actual_duration

      if duration_shortfall > 5 # More than 5 min short
        duration_penalty = [duration_shortfall, 40].min # Max 40 point penalty
        sqs -= duration_penalty
        components['duration_penalty'] = duration_penalty
        components['duration_shortfall_minutes'] = duration_shortfall.round
      end
    end

    # Tech issue penalty
    if session.tech_issue
      tech_penalty = 10
      sqs -= tech_penalty
      components['tech_penalty'] = tech_penalty
    end

    # Ensure SQS is between 0 and 100
    sqs = [[sqs, 0].max, 100].min

    Score.create!(
      session: session,
      tutor: session.tutor,
      score_type: 'sqs',
      value: sqs,
      components: components,
      computed_at: Time.current
    )
  end

  def compute_fsrs(session)
    transcript = session.session_transcript
    return unless transcript&.payload&.dig('text').present?

    text = transcript.payload['text'].downcase
    fsrs = 0.0
    components = {}

    # Confusion phrases (weight: 15 points)
    confusion_patterns = [
      /\bi don'?t understand\b/,
      /\bconfus(ed|ing)\b/,
      /\bwhat do you mean\b/,
      /\bcan you explain\b/,
      /\bi'?m lost\b/
    ]
    confusion_count = confusion_patterns.sum { |pattern| text.scan(pattern).count }
    if confusion_count > 0
      confusion_penalty = [confusion_count * 15, 30].min
      fsrs += confusion_penalty
      components['confusion_phrases'] = confusion_count
    end

    # Negative phrasing (weight: 10 points)
    negative_patterns = [
      /\byou should\b/,
      /\byou need to\b/,
      /\byou have to\b/,
      /\byou must\b/,
      /\bthat'?s wrong\b/,
      /\bdon'?t do that\b/
    ]
    negative_count = negative_patterns.sum { |pattern| text.scan(pattern).count }
    if negative_count > 0
      negative_penalty = [negative_count * 10, 20].min
      fsrs += negative_penalty
      components['negative_phrasing'] = negative_count
    end

    # Missing goal-setting (weight: 15 points)
    goal_patterns = [
      /\bwhat are your goals\b/,
      /\bwhat do you want to achieve\b/,
      /\bwhat would you like to work on\b/
    ]
    has_goal_setting = goal_patterns.any? { |pattern| text.match?(pattern) }
    unless has_goal_setting
      fsrs += 15
      components['missing_goal_setting'] = 1
    end

    # Word share imbalance (weight: 10 points)
    words = text.split
    tutor_indicators = words.count { |w| w.match?(/\b(i|me|my|we)\b/) }
    student_indicators = words.count { |w| w.match?(/\b(you|your)\b/) }
    
    if tutor_indicators > student_indicators * 2
      fsrs += 10
      components['word_share_imbalance'] = 1
    end

    # Missing encouragement (weight: 10 points)
    encouragement_patterns = [
      /\bgreat job\b/,
      /\bwell done\b/,
      /\bexcellent\b/,
      /\bgood work\b/,
      /\byou'?re doing well\b/
    ]
    has_encouragement = encouragement_patterns.any? { |pattern| text.match?(pattern) }
    unless has_encouragement
      fsrs += 10
      components['missing_encouragement'] = 1
    end

    # Missing closing summary (weight: 10 points)
    closing_patterns = [
      /\bto summarize\b/,
      /\bin summary\b/,
      /\bnext time\b/,
      /\bfor next session\b/
    ]
    has_closing = closing_patterns.any? { |pattern| text.match?(pattern) }
    unless has_closing
      fsrs += 10
      components['missing_closing_summary'] = 1
    end

    # Tech/lateness disruption (weight: 10 points)
    if session.tech_issue
      fsrs += 10
      components['tech_lateness_disruption'] = 1
    end

    # Ensure FSRS is non-negative
    fsrs = [fsrs, 0].max

    Score.create!(
      session: session,
      tutor: session.tutor,
      score_type: 'fsrs',
      value: fsrs,
      components: components,
      computed_at: Time.current
    )
  end
end

