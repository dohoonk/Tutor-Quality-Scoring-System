module TranscriptAnalysis
  extend ActiveSupport::Concern

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

  GREETING_PHRASES = [
    'hello', 'hi', 'hey', 'good morning', 'good afternoon', 'good evening',
    'nice to meet you', 'pleased to meet you', 'how are you', 'how\'s it going'
  ].freeze

  INTRO_BACKGROUND_PHRASES = [
    'my name is', 'i am', 'i\'m', 'i teach', 'i specialize in',
    'tell me about yourself', 'what\'s your background', 'where are you from',
    'what do you study', 'what grade are you', 'what level are you',
    'introduce yourself', 'a little about me'
  ].freeze

  FUTURE_SESSION_PHRASES = [
    'next time', 'next session', 'in our next meeting', 'for next week',
    'next class', 'next lesson', 'we\'ll cover', 'we will work on',
    'plan for next', 'homework for', 'prepare for next'
  ].freeze

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

    # Penalty: 20 points if student expressed confusion 3+ times
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
    # Penalty: 20 points if tutor speaks >75% of the time
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

    # Penalty: 20 points if no goal-setting question in first 3 turns
    20
  end

  def detect_missing_encouragement
    tutor_turns = get_tutor_turns
    
    tutor_turns.each do |turn|
      text = turn['text']&.downcase || ''
      ENCOURAGEMENT_PHRASES.each do |phrase|
        return 0 if text.include?(phrase)
      end
    end

    # Penalty: 10 points if no encouragement phrases used
    10
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

    # Penalty: 5 points if 2+ negative phrases used
    negative_count >= 2 ? 5 : 0
  end

  def detect_missing_closing_summary
    # Check last 3 tutor turns for closing phrases
    tutor_turns = get_tutor_turns.last(3)
    return 15 if tutor_turns.empty?
    
    tutor_turns.each do |turn|
      text = turn['text']&.downcase || ''
      CLOSING_PHRASES.each do |phrase|
        return 0 if text.include?(phrase)
      end
    end

    # Penalty: 15 points if no closing summary
    15
  end

  def detect_missing_greeting
    # Check first 2 tutor turns for greeting phrases
    tutor_turns = get_tutor_turns.first(2)
    return 15 if tutor_turns.empty?
    
    tutor_turns.each do |turn|
      text = turn['text']&.downcase || ''
      GREETING_PHRASES.each do |phrase|
        return 0 if text.include?(phrase)
      end
    end

    # Penalty: 15 points if no greeting in first 2 turns
    15
  end

  def detect_missing_intro_background
    # Check first 5 tutor turns for intro/background phrases
    tutor_turns = get_tutor_turns.first(5)
    return 15 if tutor_turns.empty?
    
    tutor_turns.each do |turn|
      text = turn['text']&.downcase || ''
      INTRO_BACKGROUND_PHRASES.each do |phrase|
        return 0 if text.include?(phrase)
      end
    end

    # Penalty: 15 points if no intro/background in first 5 turns
    15
  end

  def detect_missing_future_session_planning
    # Check last 5 tutor turns for future session planning phrases
    tutor_turns = get_tutor_turns.last(5)
    return 15 if tutor_turns.empty?
    
    tutor_turns.each do |turn|
      text = turn['text']&.downcase || ''
      FUTURE_SESSION_PHRASES.each do |phrase|
        return 0 if text.include?(phrase)
      end
    end

    # Penalty: 15 points if no future session planning
    15
  end
end

