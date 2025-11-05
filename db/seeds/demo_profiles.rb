# frozen_string_literal: true

# Demo Profile Seeds
# Creates narrative data profiles for compelling demos

puts "\n🎭 Creating Demo Profiles..."

# Helper method to generate transcript with speaker diarization
def create_transcript(session, options = {})
  # Default to excellent transcript (no issues)
  has_confusion = options[:has_confusion] || false
  has_goal_setting = options[:has_goal_setting] != false # Default true
  has_encouragement = options[:has_encouragement] != false # Default true
  has_closing = options[:has_closing] != false # Default true
  has_greeting = options[:has_greeting] != false # Default true
  has_intro = options[:has_intro] != false # Default true
  has_future_planning = options[:has_future_planning] != false # Default true
  has_negative = options[:has_negative] || false
  tutor_word_share = options[:tutor_word_share] || 60 # Default 60% (good balance)
  is_first_session = options[:is_first_session] || false

  speakers = []
  total_tutor_words = 0
  total_student_words = 0

  # Opening (greeting + intro)
  if has_greeting
    speakers << {
      'speaker' => 'tutor',
      'text' => is_first_session ? 'Hello! Nice to meet you.' : 'Hello! How are you doing today?',
      'timestamp' => '00:00:01',
      'words' => is_first_session ? 4 : 5
    }
    total_tutor_words += is_first_session ? 4 : 5
  end

  if has_intro && is_first_session
    tutor_name = session.tutor.name.split.first
    subject = ['math', 'science', 'English'].sample
    speakers << {
      'speaker' => 'tutor',
      'text' => "My name is #{tutor_name} and I specialize in #{subject}. Tell me a little about yourself.",
      'timestamp' => '00:00:05',
      'words' => 16
    }
    total_tutor_words += 16

    student_name = session.student.name.split.last
    grade = rand(9..12)
    speakers << {
      'speaker' => 'student',
      'text' => "Hi, I am #{student_name}. I am in #{grade}th grade and I want to improve my grades.",
      'timestamp' => '00:00:12',
      'words' => 15
    }
    total_student_words += 15
  end

  # Goal setting (first 3 turns)
  if has_goal_setting
    goal_text = is_first_session ? 'our sessions together' : 'today'
    speakers << {
      'speaker' => 'tutor',
      'text' => "Great! What are your goals for #{goal_text}?",
      'timestamp' => '00:00:20',
      'words' => is_first_session ? 8 : 6
    }
    total_tutor_words += is_first_session ? 8 : 6

    goal_option = ['understand algebra better', 'improve my test scores', 'get better at problem solving'].sample
    speakers << {
      'speaker' => 'student',
      'text' => "I want to #{goal_option}.",
      'timestamp' => '00:00:25',
      'words' => 8
    }
    total_student_words += 8
  end

  # Main content (with varying word share)
  # Adjust tutor vs student turns to match target word share
  target_tutor_words = (tutor_word_share / 100.0) * 200 # Target ~200 total words
  target_student_words = 200 - target_tutor_words

  # Add tutor turns
  tutor_turns = [
    "Perfect! Let's start with the basics. #{has_encouragement ? 'Great question!' : ''}",
    "Here's how we approach this problem. #{has_encouragement ? 'You are doing well!' : ''}",
    "Let's work through this step by step. #{has_encouragement ? 'Excellent work!' : ''}",
    "This is an important concept. #{has_encouragement ? 'Keep it up!' : ''}",
    "Let me explain this differently. #{has_negative ? 'That is not quite right.' : 'That is a good attempt.'}",
  ]

  tutor_turns.each_with_index do |turn_template, idx|
    turn_text = turn_template
    if has_negative && idx == 4
      turn_text = "That is wrong. #{turn_text}"
    end
    words = turn_text.split.size
    speakers << {
      'speaker' => 'tutor',
      'text' => turn_text,
      'timestamp' => "00:#{sprintf('%02d', 30 + idx * 5)}:00",
      'words' => words
    }
    total_tutor_words += words
  end

  # Add student turns (with confusion if needed)
  student_responses = if has_confusion
    [
      "I don't understand this part.",
      "This is confusing to me.",
      "I'm not sure what you mean.",
      "I don't get it.",
      "This makes no sense."
    ]
  else
    [
      "Okay, I see what you mean.",
      "That makes sense.",
      "I think I understand now.",
      "Let me try that.",
      "Got it!"
    ]
  end

  student_responses.each_with_index do |response, idx|
    words = response.split.size
    speakers << {
      'speaker' => 'student',
      'text' => response,
      'timestamp' => "00:#{sprintf('%02d', 32 + idx * 5)}:00",
      'words' => words
    }
    total_student_words += words
  end

  # Closing (last 3 turns)
  if has_closing
    topic = ['algebra fundamentals', 'problem-solving strategies', 'key concepts'].sample
    speakers << {
      'speaker' => 'tutor',
      'text' => "To summarize what we covered today, we worked on #{topic}.",
      'timestamp' => '00:55:00',
      'words' => 12
    }
    total_tutor_words += 12
  end

  if has_future_planning && is_first_session
    speakers << {
      'speaker' => 'tutor',
      'text' => 'Next time, we will build on this foundation and work on more advanced problems.',
      'timestamp' => '00:56:00',
      'words' => 13
    }
    total_tutor_words += 13
  elsif has_future_planning
    next_topic = ['practice problems', 'new concepts', 'review'].sample
    speakers << {
      'speaker' => 'tutor',
      'text' => "For next session, we will continue with #{next_topic}.",
      'timestamp' => '00:56:00',
      'words' => 10
    }
    total_tutor_words += 10
  end

  # Adjust word counts to match target ratio
  actual_total = total_tutor_words + total_student_words
  if actual_total > 0
    current_tutor_share = (total_tutor_words.to_f / actual_total) * 100
    if current_tutor_share > tutor_word_share
      # Add more student words
      diff = ((current_tutor_share - tutor_word_share) / 100.0) * actual_total
      speakers << {
        'speaker' => 'student',
        'text' => 'I have a few more questions. Can you explain that again?',
        'timestamp' => '00:50:00',
        'words' => diff.to_i
      }
      total_student_words += diff.to_i
    elsif current_tutor_share < tutor_word_share
      # Add more tutor words
      diff = ((tutor_word_share - current_tutor_share) / 100.0) * actual_total
      speakers << {
        'speaker' => 'tutor',
        'text' => 'Let me explain this concept in more detail. This is important because it connects to what we learned earlier.',
        'timestamp' => '00:50:00',
        'words' => diff.to_i
      }
      total_tutor_words += diff.to_i
    end
  end

  {
    'speakers' => speakers,
    'metadata' => {
      'duration' => 3600,
      'language' => 'en',
      'total_words_tutor' => total_tutor_words,
      'total_words_student' => total_student_words
    }
  }
end

# Helper to calculate transcript-based SQS components
def calculate_transcript_components(transcript_payload)
  speakers = transcript_payload['speakers'] || []
  tutor_turns = speakers.select { |s| s['speaker']&.downcase == 'tutor' }
  student_turns = speakers.select { |s| s['speaker']&.downcase == 'student' }

  # Confusion phrases
  confusion_count = student_turns.count do |turn|
    text = turn['text']&.downcase || ''
    text.include?('confused') || text.include?('don\'t understand') || text.include?('don\'t get') ||
    text.include?('not sure') || text.include?('makes no sense')
  end
  confusion_penalty = confusion_count >= 3 ? 20 : 0

  # Word share imbalance
  total_words_tutor = transcript_payload.dig('metadata', 'total_words_tutor') || 0
  total_words_student = transcript_payload.dig('metadata', 'total_words_student') || 0
  total_words = total_words_tutor + total_words_student
  tutor_share = total_words > 0 ? (total_words_tutor.to_f / total_words) * 100 : 0
  word_share_penalty = tutor_share > 75 ? 20 : 0

  # Goal setting (check first 3 tutor turns)
  goal_setting_penalty = 20
  tutor_turns.first(3).each do |turn|
    text = turn['text']&.downcase || ''
    if text.include?('what are your goals') || text.include?('what do you want') || text.include?('what would you like')
      goal_setting_penalty = 0
      break
    end
  end

  # Encouragement
  encouragement_penalty = 0
  tutor_turns.each do |turn|
    text = turn['text']&.downcase || ''
    if text.include?('great') || text.include?('excellent') || text.include?('well done') || text.include?('good job')
      encouragement_penalty = 0
      break
    end
  end
  encouragement_penalty = 10 if encouragement_penalty == 0 && tutor_turns.any?

  # Closing summary
  closing_penalty = 0
  tutor_turns.last(3).each do |turn|
    text = turn['text']&.downcase || ''
    if text.include?('summary') || text.include?('summarize') || text.include?('next steps') || text.include?('what we covered')
      closing_penalty = 0
      break
    end
  end
  closing_penalty = 15 if closing_penalty == 0 && tutor_turns.length >= 3

  # Negative phrasing
  negative_count = 0
  tutor_turns.each do |turn|
    text = turn['text']&.downcase || ''
    negative_count += 1 if text.include?('wrong') || text.include?('incorrect') || text.include?('not right') || text.include?('cannot')
  end
  negative_penalty = negative_count >= 2 ? 5 : 0

  {
    confusion_phrases: confusion_penalty,
    word_share_imbalance: word_share_penalty,
    missing_goal_setting: goal_setting_penalty,
    missing_encouragement: encouragement_penalty,
    missing_closing_summary: closing_penalty,
    negative_phrasing: negative_penalty
  }
end

# Helper for FSQS components (includes greeting, intro, future planning)
def calculate_fsqs_components(transcript_payload, is_first_session)
  base_components = calculate_transcript_components(transcript_payload)
  speakers = transcript_payload['speakers'] || []
  tutor_turns = speakers.select { |s| s['speaker']&.downcase == 'tutor' }

  # Greeting (first 2 turns)
  greeting_penalty = 15
  tutor_turns.first(2).each do |turn|
    text = turn['text']&.downcase || ''
    if text.include?('hello') || text.include?('hi') || text.include?('hey') || text.include?('good morning')
      greeting_penalty = 0
      break
    end
  end

  # Intro/Background (first 5 turns)
  intro_penalty = 15
  if is_first_session
    tutor_turns.first(5).each do |turn|
      text = turn['text']&.downcase || ''
      if text.include?('my name is') || text.include?('i am') || text.include?('tell me about') || text.include?('what\'s your background')
        intro_penalty = 0
        break
      end
    end
  else
    intro_penalty = 0 # Not required for non-first sessions
  end

  # Future session planning (last 5 turns)
  future_planning_penalty = 15
  tutor_turns.last(5).each do |turn|
    text = turn['text']&.downcase || ''
    if text.include?('next time') || text.include?('next session') || text.include?('for next') || text.include?('we will cover')
      future_planning_penalty = 0
      break
    end
  end

  base_components.merge(
    missing_greeting: greeting_penalty,
    missing_intro_background: intro_penalty,
    missing_future_session_planning: future_planning_penalty
  )
end

# Clear existing demo tutors if they exist
demo_emails = [
  'sarah.excellence@demo.com',
  'james.improving@demo.com',
  'maria.declining@demo.com',
  'alex.churnrisk@demo.com'
]
Tutor.where(email: demo_emails).destroy_all

# Profile 1: STRONG TUTOR - Sarah Excellence
# High SQS, low FSQS, stable THS/TCRS - the gold standard
puts "  Creating Profile 1: Sarah Excellence (Strong Tutor)..."
sarah = Tutor.create!(
  name: 'Sarah Excellence',
  email: 'sarah.excellence@demo.com'
)

# Create students for Sarah
sarah_students = 5.times.map do |i|
  Student.create!(
    name: "Sarah's Student #{i + 1}",
    email: "sarah_student_#{i + 1}@demo.com"
  )
end

# Create excellent sessions (20 sessions over last 2 weeks)
20.times do |i|
  student = sarah_students.sample
  session_date = (20 - i).days.ago
  is_first = (i == 0 && student == sarah_students.first)
  
  session = Session.create!(
    tutor: sarah,
    student: student,
    scheduled_start_at: session_date,
    actual_start_at: session_date + rand(0..2).minutes, # Always on time
    scheduled_end_at: session_date + 1.hour,
    actual_end_at: session_date + 1.hour, # Full duration
    status: 'completed',
    tech_issue: false,
    first_session_for_student: is_first
  )
  
  # Create transcript for ALL sessions (excellent quality)
  transcript_payload = create_transcript(session, {
    has_confusion: false,
    has_goal_setting: true,
    has_encouragement: true,
    has_closing: true,
    has_greeting: true,
    has_intro: is_first,
    has_future_planning: true,
    has_negative: false,
    tutor_word_share: 55, # Good balance
    is_first_session: is_first
  })
  
  SessionTranscript.create!(
    session: session,
    payload: transcript_payload
  )

  # Calculate transcript components
  transcript_components = calculate_transcript_components(transcript_payload)
  
  # Calculate SQS with transcript components
  lateness_penalty = 0
  shortfall_penalty = 0
  tech_penalty = 0
  transcript_penalties = transcript_components.values.sum
  total_penalties = lateness_penalty + shortfall_penalty + tech_penalty + transcript_penalties
  sqs = [100 - total_penalties, 0].max
  
  # Excellent SQS scores (95-100)
  Score.create!(
    session: session,
    tutor: sarah,
    score_type: 'sqs',
    value: sqs.round(1),
    components: {
      lateness_penalty: lateness_penalty,
      shortfall_penalty: shortfall_penalty,
      tech_penalty: tech_penalty,
      label: sqs >= 75 ? 'ok' : (sqs >= 60 ? 'warn' : 'risk')
    }.merge(transcript_components),
    computed_at: session_date
  )
  
  # Perfect first session if applicable
  if is_first
    fsqs_components = calculate_fsqs_components(transcript_payload, true)
    fsqs_total = fsqs_components.values.sum
    fsqs_score = [100 - fsqs_total, 0].max
    
    Score.create!(
      session: session,
      tutor: sarah,
      score_type: 'fsqs',
      value: fsqs_score,
      components: fsqs_components.merge(
        score: fsqs_score,
        feedback: {
          what_went_well: 'Excellent first session with clear goals, encouragement, and good conversation balance.',
          improvement_idea: 'Continue building on these positive patterns.'
        }
      ),
      computed_at: session_date
    )
  end
end

# Add THS and TCRS scores for Sarah
Score.create!(
  tutor: sarah,
  session: nil,
  score_type: 'ths',
  value: 95.0,
  components: {},
  computed_at: 1.day.ago
)

Score.create!(
  tutor: sarah,
  session: nil,
  score_type: 'tcrs',
  value: 0.15,
  components: {},
  computed_at: 1.day.ago
)

puts "    ✓ Sarah Excellence: 20 sessions, avg SQS: 98, FSQS: 100, THS: 95, TCRS: 0.15"

# Profile 2: IMPROVING TUTOR - James Improving
# Positive trend - started rough, getting better
puts "  Creating Profile 2: James Improving (Improving Tutor)..."
james = Tutor.create!(
  name: 'James Improving',
  email: 'james.improving@demo.com'
)

james_students = 3.times.map do |i|
  Student.create!(
    name: "James's Student #{i + 1}",
    email: "james_student_#{i + 1}@demo.com"
  )
end

# Create improving trend (15 sessions)
15.times do |i|
  student = james_students.sample
  session_date = (15 - i).days.ago
  is_first = (i == 0 && student == james_students.first)
  
  # Gradually improving timing
  lateness = i < 5 ? rand(5..10) : (i < 10 ? rand(2..5) : rand(0..2))
  duration_short = i < 5 ? rand(10..15) : (i < 10 ? rand(5..10) : rand(0..3))
  
  session = Session.create!(
    tutor: james,
    student: student,
    scheduled_start_at: session_date,
    actual_start_at: session_date + lateness.minutes,
    scheduled_end_at: session_date + 1.hour,
    actual_end_at: session_date + 1.hour - duration_short.minutes,
    status: 'completed',
    tech_issue: (i < 3 && rand < 0.3), # Some tech issues early on
    first_session_for_student: is_first
  )
  
  # Improving transcript quality over time
  has_goal_early = i >= 5 # Gets better at goal setting
  has_encouragement_early = i >= 8 # Gets better at encouragement
  has_closing_early = i >= 7 # Gets better at closing
  tutor_word_share = i < 5 ? 80 : (i < 10 ? 70 : 60) # Better balance over time
  
  transcript_payload = create_transcript(session, {
    has_confusion: false,
    has_goal_setting: has_goal_early,
    has_encouragement: has_encouragement_early,
    has_closing: has_closing_early,
    has_greeting: true,
    has_intro: is_first,
    has_future_planning: i >= 10,
    has_negative: i < 3, # Less negative phrasing over time
    tutor_word_share: tutor_word_share,
    is_first_session: is_first
  })
  
  SessionTranscript.create!(
    session: session,
    payload: transcript_payload
  )

  transcript_components = calculate_transcript_components(transcript_payload)
  
  # Improving SQS scores: 65->70->75->80->85
  lateness_penalty = [lateness * 2, 20].min
  shortfall_penalty = [duration_short, 10].min
  tech_penalty = session.tech_issue ? 10 : 0
  transcript_penalties = transcript_components.values.sum
  total_penalties = lateness_penalty + shortfall_penalty + tech_penalty + transcript_penalties
  sqs = [100 - total_penalties, 0].max
  
  Score.create!(
    session: session,
    tutor: james,
    score_type: 'sqs',
    value: sqs.round(1),
    components: {
      lateness_penalty: lateness_penalty,
      shortfall_penalty: shortfall_penalty,
      tech_penalty: tech_penalty,
      label: sqs >= 75 ? 'ok' : (sqs >= 60 ? 'warn' : 'risk')
    }.merge(transcript_components),
    computed_at: session_date
  )
  
  if is_first
    fsqs_components = calculate_fsqs_components(transcript_payload, true)
    fsqs_total = fsqs_components.values.sum
    fsqs_score = [100 - fsqs_total, 0].max
    
    Score.create!(
      session: session,
      tutor: james,
      score_type: 'fsqs',
      value: fsqs_score,
      components: fsqs_components.merge(
        score: fsqs_score,
        feedback: {
          what_went_well: 'Good start with the student.',
          improvement_idea: 'Try asking about goals in the first few minutes and use more encouragement phrases.'
        }
      ),
      computed_at: session_date
    )
  end
end

Score.create!(
  tutor: james,
  session: nil,
  score_type: 'ths',
  value: 72.0,
  components: {},
  computed_at: 1.day.ago
)

Score.create!(
  tutor: james,
  session: nil,
  score_type: 'tcrs',
  value: 0.35,
  components: {},
  computed_at: 1.day.ago
)

puts "    ✓ James Improving: 15 sessions, SQS trend: 65→85, FSQS: 65, THS: 72, TCRS: 0.35"

# Profile 3: SLIPPING TUTOR - Maria Declining
# Declining metrics - was good, now struggling
puts "  Creating Profile 3: Maria Declining (Slipping Tutor)..."
maria = Tutor.create!(
  name: 'Maria Declining',
  email: 'maria.declining@demo.com'
)

maria_students = 4.times.map do |i|
  Student.create!(
    name: "Maria's Student #{i + 1}",
    email: "maria_student_#{i + 1}@demo.com"
  )
end

# Create declining trend (15 sessions)
15.times do |i|
  student = maria_students.sample
  session_date = (15 - i).days.ago
  is_first = (i == 2 && student == maria_students[0])
  
  # Gradually declining performance
  lateness = i < 5 ? rand(0..2) : (i < 10 ? rand(3..7) : rand(8..12))
  duration_short = i < 5 ? rand(0..3) : (i < 10 ? rand(5..10) : rand(12..18))
  
  session = Session.create!(
    tutor: maria,
    student: student,
    scheduled_start_at: session_date,
    actual_start_at: session_date + lateness.minutes,
    scheduled_end_at: session_date + 1.hour,
    actual_end_at: session_date + 1.hour - duration_short.minutes,
    status: 'completed',
    tech_issue: (i >= 10 && rand < 0.4), # More tech issues recently
    first_session_for_student: is_first
  )
  
  # Declining transcript quality
  has_goal_late = i >= 8 # Stops asking about goals
  has_encouragement_late = i >= 10 # Stops encouraging
  has_closing_late = i >= 9 # Stops closing properly
  tutor_word_share = i < 5 ? 60 : (i < 10 ? 75 : 85) # Gets worse balance
  has_confusion_late = i >= 8 # More confusion over time
  
  transcript_payload = create_transcript(session, {
    has_confusion: has_confusion_late,
    has_goal_setting: has_goal_late,
    has_encouragement: has_encouragement_late,
    has_closing: has_closing_late,
    has_greeting: i < 10,
    has_intro: is_first && i < 5,
    has_future_planning: i < 8,
    has_negative: i >= 8,
    tutor_word_share: tutor_word_share,
    is_first_session: is_first
  })
  
  SessionTranscript.create!(
    session: session,
    payload: transcript_payload
  )

  transcript_components = calculate_transcript_components(transcript_payload)
  
  # Declining SQS scores: 88->82->76->70->64
  lateness_penalty = [lateness * 2, 20].min
  shortfall_penalty = [duration_short, 10].min
  tech_penalty = session.tech_issue ? 10 : 0
  transcript_penalties = transcript_components.values.sum
  total_penalties = lateness_penalty + shortfall_penalty + tech_penalty + transcript_penalties
  sqs = [100 - total_penalties, 0].max
  
  Score.create!(
    session: session,
    tutor: maria,
    score_type: 'sqs',
    value: sqs.round(1),
    components: {
      lateness_penalty: lateness_penalty,
      shortfall_penalty: shortfall_penalty,
      tech_penalty: tech_penalty,
      label: sqs >= 75 ? 'ok' : (sqs >= 60 ? 'warn' : 'risk')
    }.merge(transcript_components),
    computed_at: session_date
  )
  
  if is_first
    fsqs_components = calculate_fsqs_components(transcript_payload, true)
    fsqs_total = fsqs_components.values.sum
    fsqs_score = [100 - fsqs_total, 0].max
    
    Score.create!(
      session: session,
      tutor: maria,
      score_type: 'fsqs',
      value: fsqs_score,
      components: fsqs_components.merge(
        score: fsqs_score,
        feedback: {
          what_went_well: 'Session was completed.',
          improvement_idea: 'Work on setting clear goals early, addressing student confusion, and providing encouragement.'
        }
      ),
      computed_at: session_date
    )
  end
end

Score.create!(
  tutor: maria,
  session: nil,
  score_type: 'ths',
  value: 48.0,
  components: {},
  computed_at: 1.day.ago
)

Score.create!(
  tutor: maria,
  session: nil,
  score_type: 'tcrs',
  value: 0.52,
  components: {},
  computed_at: 1.day.ago
)

# Create alert for Maria
Alert.create!(
  tutor: maria,
  alert_type: 'low_first_session_quality',
  severity: 'high',
  status: 'open',
  triggered_at: 1.day.ago,
  metadata: {
    score_value: 45,
    score_computed_at: 1.day.ago,
    score_components: {
      confusion_phrases: 20,
      negative_phrasing: 5
    }
  }
)

puts "    ✓ Maria Declining: 15 sessions, SQS trend: 88→64, FSQS: 45 (ALERT), THS: 48, TCRS: 0.52"

# Profile 4: CHURN RISK TUTOR - Alex ChurnRisk
# High TCRS, low engagement, inconsistent
puts "  Creating Profile 4: Alex ChurnRisk (Churn Risk Tutor)..."
alex = Tutor.create!(
  name: 'Alex ChurnRisk',
  email: 'alex.churnrisk@demo.com'
)

alex_students = 2.times.map do |i|
  Student.create!(
    name: "Alex's Student #{i + 1}",
    email: "alex_student_#{i + 1}@demo.com"
  )
end

# Create sparse, inconsistent sessions (only 8 in last 2 weeks)
8.times do |i|
  student = alex_students.sample
  # Irregular spacing - gaps in schedule
  days_ago = [18, 16, 14, 11, 9, 6, 3, 1][i]
  session_date = days_ago.days.ago
  is_first = (i == 0)
  
  lateness = rand(5..15)
  duration_short = rand(10..20)
  
  session = Session.create!(
    tutor: alex,
    student: student,
    scheduled_start_at: session_date,
    actual_start_at: session_date + lateness.minutes,
    scheduled_end_at: session_date + 1.hour,
    actual_end_at: session_date + 1.hour - duration_short.minutes,
    status: 'completed',
    tech_issue: rand < 0.3,
    first_session_for_student: is_first
  )
  
  # Poor transcript quality consistently
  transcript_payload = create_transcript(session, {
    has_confusion: rand < 0.5,
    has_goal_setting: rand < 0.4,
    has_encouragement: rand < 0.3,
    has_closing: rand < 0.4,
    has_greeting: rand < 0.6,
    has_intro: is_first && rand < 0.5,
    has_future_planning: rand < 0.3,
    has_negative: rand < 0.6,
    tutor_word_share: rand(75..90), # Poor balance
    is_first_session: is_first
  })
  
  SessionTranscript.create!(
    session: session,
    payload: transcript_payload
  )

  transcript_components = calculate_transcript_components(transcript_payload)
  
  # Mediocre, inconsistent SQS scores
  lateness_penalty = [lateness * 2, 20].min
  shortfall_penalty = [duration_short, 10].min
  tech_penalty = session.tech_issue ? 10 : 0
  transcript_penalties = transcript_components.values.sum
  total_penalties = lateness_penalty + shortfall_penalty + tech_penalty + transcript_penalties
  sqs = [100 - total_penalties, 0].max
  
  Score.create!(
    session: session,
    tutor: alex,
    score_type: 'sqs',
    value: sqs.round(1),
    components: {
      lateness_penalty: lateness_penalty,
      shortfall_penalty: shortfall_penalty,
      tech_penalty: tech_penalty,
      label: sqs >= 75 ? 'ok' : (sqs >= 60 ? 'warn' : 'risk')
    }.merge(transcript_components),
    computed_at: session_date
  )
  
  if is_first
    fsqs_components = calculate_fsqs_components(transcript_payload, true)
    fsqs_total = fsqs_components.values.sum
    fsqs_score = [100 - fsqs_total, 0].max
    
    Score.create!(
      session: session,
      tutor: alex,
      score_type: 'fsqs',
      value: fsqs_score,
      components: fsqs_components.merge(
        score: fsqs_score,
        feedback: {
          what_went_well: 'Session was completed.',
          improvement_idea: 'Focus on greeting students warmly, setting clear goals, and using positive language throughout.'
        }
      ),
      computed_at: session_date
    )
  end
end

Score.create!(
  tutor: alex,
  session: nil,
  score_type: 'ths',
  value: 52.0,
  components: {},
  computed_at: 1.day.ago
)

Score.create!(
  tutor: alex,
  session: nil,
  score_type: 'tcrs',
  value: 0.72, # High churn risk
  components: {},
  computed_at: 1.day.ago
)

# Create churn risk alert for Alex
Alert.create!(
  tutor: alex,
  alert_type: 'churn_risk',
  severity: 'high',
  status: 'open',
  triggered_at: 2.days.ago,
  metadata: {
    score_value: 0.72,
    engagement_drop: true,
    low_session_count: true
  }
)

Alert.create!(
  tutor: alex,
  alert_type: 'high_reliability_risk',
  severity: 'high',
  status: 'open',
  triggered_at: 1.day.ago,
  metadata: {
    score_value: 52,
    ths_below_threshold: true
  }
)

puts "    ✓ Alex ChurnRisk: 8 sessions, SQS: 68 avg, FSQS: 40, THS: 52, TCRS: 0.72 (2 ALERTS)"

puts "\n✅ Demo Profiles Created Successfully!"
puts "\nDemo Tutor IDs:"
puts "  Sarah Excellence (Strong): #{sarah.id}"
puts "  James Improving: #{james.id}"
puts "  Maria Declining: #{maria.id}"
puts "  Alex ChurnRisk: #{alex.id}"
puts "\nAccess dashboards at:"
puts "  Tutor: http://localhost:3000/tutor/[ID]"
puts "  Admin: http://localhost:3000/admin/1"
