class FirstSessionRiskScoreService
  CONFUSION_PHRASES = [
    'do not understand', 'do not get', 'confused', 'unclear', 'not clear',
    'do not know', 'unsure', 'lost', 'do not follow', 'makes no sense'
  ].freeze

  ENCOURAGEMENT_PHRASES = [
    'great', 'excellent', 'well done', 'good job', 'keep it up', 'you are doing well',
    'nice work', 'awesome', 'fantastic', 'wonderful', 'perfect', 'amazing'
  ].freeze

  GOAL_SETTING_PHRASES = [
    'what are your goals', 'what do you want to', 'what would you like to',
    'what are you hoping to', 'what are you trying to', 'what do you need help with'
  ].freeze

  NEGATIVE_PHRASES = [
    'wrong', 'incorrect', 'not right', 'failed', 'cannot', 'should not',
    'bad', 'terrible', 'horrible', 'awful', 'disappointed'
  ].freeze

  CLOSING_PHRASES = [
    'summary', 'summarize', 'next steps', 'what we covered', 'plan for',
    'review', 'recap', 'to conclude', 'in summary', 'moving forward'
  ].freeze

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
      tech_lateness_disruption: detect_tech_lateness_disruption
    }

    score = components.values.sum
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
      score_type: 'fsrs',
      value: result[:score],
      components: result[:components].merge(
        score: result[:score],
        feedback: result[:feedback]
      ),
      computed_at: Time.current
    )
  end

  private

  def transcript_present?
    @session.session_transcript.present?
  end

  def speaker_diarization_present?
    payload = @session.session_transcript&.payload
    return false unless payload.is_a?(Hash)

    speakers = payload['speakers']
    return false unless speakers.is_a?(Array)
    return false if speakers.empty?

    speakers.any? { |s| s.is_a?(Hash) && s['speaker'].present? }
  end

  def get_speakers
    @session.session_transcript.payload['speakers'] || []
  end

  def get_student_turns
    get_speakers.select { |s| s['speaker']&.downcase == 'student' }
  end

  def get_tutor_turns
    get_speakers.select { |s| s['speaker']&.downcase == 'tutor' }
  end

  def detect_confusion_phrases
    student_turns = get_student_turns
    confusion_count = 0

    student_turns.each do |turn|
      text = turn['text']&.downcase || ''
      CONFUSION_PHRASES.each do |phrase|
        confusion_count += 1 if text.include?(phrase)
      end
    end

    confusion_count >= 3 ? 20 : 0
  end

  def detect_word_share_imbalance
    payload = @session.session_transcript.payload
    total_words_tutor = payload.dig('metadata', 'total_words_tutor') || 0
    total_words_student = payload.dig('metadata', 'total_words_student') || 0

    # If metadata not available, calculate from speakers
    if total_words_tutor == 0 && total_words_student == 0
      total_words_tutor = get_tutor_turns.sum { |t| t['words'] || 0 }
      total_words_student = get_student_turns.sum { |t| t['words'] || 0 }
    end

    total_words = total_words_tutor + total_words_student
    return 0 if total_words == 0

    tutor_share = (total_words_tutor.to_f / total_words) * 100
    tutor_share > 75 ? 20 : 0
  end

  def detect_missing_goal_setting
    # Check first 3 tutor turns for goal-setting question
    tutor_turns = get_tutor_turns.first(3)
    
    tutor_turns.each do |turn|
      text = turn['text']&.downcase || ''
      GOAL_SETTING_PHRASES.each do |phrase|
        return 0 if text.include?(phrase)
      end
    end

    25
  end

  def detect_missing_encouragement
    tutor_turns = get_tutor_turns
    
    tutor_turns.each do |turn|
      text = turn['text']&.downcase || ''
      ENCOURAGEMENT_PHRASES.each do |phrase|
        return 0 if text.include?(phrase)
      end
    end

    15
  end

  def detect_negative_phrasing
    tutor_turns = get_tutor_turns
    negative_count = 0

    tutor_turns.each do |turn|
      text = turn['text']&.downcase || ''
      NEGATIVE_PHRASES.each do |phrase|
        negative_count += 1 if text.include?(phrase)
      end
    end

    negative_count >= 2 ? 10 : 0
  end

  def detect_missing_closing_summary
    # Check last 3 tutor turns for closing phrases
    tutor_turns = get_tutor_turns.last(3)
    return 20 if tutor_turns.empty?
    
    tutor_turns.each do |turn|
      text = turn['text']&.downcase || ''
      CLOSING_PHRASES.each do |phrase|
        return 0 if text.include?(phrase)
      end
    end

    20
  end

  def detect_tech_lateness_disruption
    has_tech_issue = @session.tech_issue || false
    
    has_lateness = false
    if @session.actual_start_at && @session.scheduled_start_at
      lateness_minutes = ((@session.actual_start_at - @session.scheduled_start_at) / 60.0).ceil
      has_lateness = lateness_minutes > 5 # More than 5 minutes late
    end

    (has_tech_issue || has_lateness) ? 10 : 0
  end

  def generate_feedback(components, score)
    positive_signals = []
    issues = []

    # Identify positive signals
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

    # Identify issues
    issues << { impact: 25, message: 'Goal-setting question should be asked early in first sessions' } if components[:missing_goal_setting] > 0
    issues << { impact: 20, message: 'Student confusion detected - consider adjusting explanation approach' } if components[:confusion_phrases] > 0
    issues << { impact: 20, message: 'Word share imbalance - student should have more opportunities to speak' } if components[:word_share_imbalance] > 0
    issues << { impact: 20, message: 'Missing closing summary - help student understand what was covered and next steps' } if components[:missing_closing_summary] > 0
    issues << { impact: 15, message: 'More encouragement phrases would help build student confidence' } if components[:missing_encouragement] > 0
    issues << { impact: 10, message: 'Negative phrasing detected - focus on constructive, positive language' } if components[:negative_phrasing] > 0
    issues << { impact: 10, message: 'Technical issues or lateness disrupted the session experience' } if components[:tech_lateness_disruption] > 0

    # Select highest impact issue
    highest_impact_issue = issues.max_by { |i| i[:impact] }

    {
      'what_went_well' => positive_signals.any? ? positive_signals.join('. ') : 'Session completed successfully',
      'improvement_idea' => highest_impact_issue ? highest_impact_issue[:message] : 'Continue building on these positive patterns',
      'breakdown' => components
    }
  end
end

