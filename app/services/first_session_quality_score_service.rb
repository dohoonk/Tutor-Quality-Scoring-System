class FirstSessionQualityScoreService
  include TranscriptAnalysis

  # FSQS (First Session Quality Score) - Higher is better
  # Score starts at 100 (perfect) and subtracts penalties for quality issues
  # Range: 0-100 where 100 = perfect first session, 0 = many issues
  
  MAX_SCORE = 100

  def initialize(session)
    @session = session
  end

  def calculate
    return nil unless @session.first_session_for_student
    return nil unless transcript_present?
    return nil unless speaker_diarization_present?

    components = {
      confusion_phrases: detect_confusion_phrases,
      word_share_imbalance: detect_word_share_imbalance,
      missing_goal_setting: detect_missing_goal_setting,
      missing_encouragement: detect_missing_encouragement,
      negative_phrasing: detect_negative_phrasing,
      missing_closing_summary: detect_missing_closing_summary,
      tech_lateness_disruption: detect_tech_lateness_disruption,
      # New metrics for FSQS
      missing_greeting: detect_missing_greeting,
      missing_intro_background: detect_missing_intro_background,
      missing_future_session_planning: detect_missing_future_session_planning
    }

    # FSQS: Start at 100 (perfect) and subtract penalties (higher is better)
    raw_score = MAX_SCORE - components.values.sum
    score = [[raw_score, 0].max, 100].min # Clamp between 0 and 100
    feedback = generate_feedback(components, score)

    {
      score: score,
      components: components,
      feedback: feedback
    }
  end

  def save_score(result)
    return unless result

    Score.create!(
      session: @session,
      tutor: @session.tutor,
      score_type: 'fsqs',
      value: result[:score],
      components: result[:components].merge(
        score: result[:score],
        feedback: result[:feedback]
      ),
      computed_at: Time.current
    )
  end

  private

  def detect_tech_lateness_disruption
    has_tech_issue = @session.tech_issue || false
    
    has_lateness = false
    if @session.actual_start_at && @session.scheduled_start_at
      lateness_minutes = ((@session.actual_start_at - @session.scheduled_start_at) / 60.0).ceil
      has_lateness = lateness_minutes > 5 # More than 5 minutes late
    end

    # Penalty: 10 points if tech issues or lateness occurred
    (has_tech_issue || has_lateness) ? 10 : 0
  end

  def generate_feedback(components, score)
    positive_signals = []
    issues = []

    # Identify positive signals (no penalty = quality present)
    if components[:confusion_phrases] == 0
      positive_signals << 'Student showed good understanding with minimal confusion'
    end
    if components[:word_share_imbalance] == 0
      positive_signals << 'Good balance of tutor and student participation'
    end
    if components[:missing_goal_setting] == 0
      positive_signals << 'Goal-setting question was asked early in the session'
    end
    if components[:missing_encouragement] == 0
      positive_signals << 'Encouragement phrases were used throughout'
    end
    if components[:negative_phrasing] == 0
      positive_signals << 'Positive, supportive language was maintained'
    end
    if components[:missing_closing_summary] == 0
      positive_signals << 'Session ended with clear summary and next steps'
    end
    if components[:missing_greeting] == 0
      positive_signals << 'Warm greeting helped set a positive tone'
    end
    if components[:missing_intro_background] == 0
      positive_signals << 'Good introduction and background discussion'
    end
    if components[:missing_future_session_planning] == 0
      positive_signals << 'Future session planning helps set expectations'
    end

    # Identify issues (penalties applied)
    issues << { impact: 20, message: 'Goal-setting question should be asked early in first sessions' } if components[:missing_goal_setting] > 0
    issues << { impact: 20, message: 'Student confusion detected - consider adjusting explanation approach' } if components[:confusion_phrases] > 0
    issues << { impact: 20, message: 'Word share imbalance - student should have more opportunities to speak' } if components[:word_share_imbalance] > 0
    issues << { impact: 15, message: 'Missing closing summary - help student understand what was covered and next steps' } if components[:missing_closing_summary] > 0
    issues << { impact: 15, message: 'Missing greeting - start with a warm welcome to make the student feel comfortable' } if components[:missing_greeting] > 0
    issues << { impact: 15, message: 'Missing intro/background - introduce yourself and learn about the student' } if components[:missing_intro_background] > 0
    issues << { impact: 15, message: 'Missing future session planning - discuss what to cover next time' } if components[:missing_future_session_planning] > 0
    issues << { impact: 10, message: 'More encouragement phrases would help build student confidence' } if components[:missing_encouragement] > 0
    issues << { impact: 10, message: 'Technical issues or lateness disrupted the session experience' } if components[:tech_lateness_disruption] > 0
    issues << { impact: 5, message: 'Negative phrasing detected - focus on constructive, positive language' } if components[:negative_phrasing] > 0

    # Select highest impact issue
    highest_impact_issue = issues.max_by { |i| i[:impact] }

    {
      'what_went_well' => positive_signals.any? ? positive_signals.join('. ') : 'Session completed successfully',
      'improvement_idea' => highest_impact_issue ? highest_impact_issue[:message] : 'Continue building on these positive patterns',
      'breakdown' => components
    }
  end
end

