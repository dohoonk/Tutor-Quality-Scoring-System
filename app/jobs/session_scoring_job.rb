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

    # Find first sessions with transcripts without FSQS scores
    first_sessions_without_fsqs = Session
      .where(status: 'completed', first_session_for_student: true)
      .joins(:session_transcript)
      .left_joins(:scores)
      .group('sessions.id')
      .having('COUNT(CASE WHEN scores.score_type = ? THEN 1 END) = 0', 'fsqs')

    first_sessions_without_fsqs.find_each do |session|
      compute_fsqs(session)
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
    
    # Bust performance summary cache when new SQS is added
    PerformanceSummaryService.bust_cache(session.tutor.id)
  end

  def compute_fsqs(session)
    # Use the FirstSessionQualityScoreService for proper FSQS calculation
    service = FirstSessionQualityScoreService.new(session)
    result = service.calculate
    service.save_score(result) if result
  end
end

