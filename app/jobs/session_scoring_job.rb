# frozen_string_literal: true

class SessionScoringJob < ApplicationJob
  queue_as :default

  def perform
    # Find completed sessions without SQS scores (with transcripts - required now)
    sessions_without_sqs = Session
      .where(status: 'completed')
      .joins(:session_transcript)
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
    # Use SessionQualityScoreService - it will return nil if transcript is missing
    service = SessionQualityScoreService.new(session)
    result = service.calculate
    service.save_score(result) if result
    
    # Bust performance summary cache when new SQS is added
    PerformanceSummaryService.bust_cache(session.tutor.id) if result
  end

  def compute_fsqs(session)
    # Use the FirstSessionQualityScoreService for proper FSQS calculation
    service = FirstSessionQualityScoreService.new(session)
    result = service.calculate
    service.save_score(result) if result
  end
end

