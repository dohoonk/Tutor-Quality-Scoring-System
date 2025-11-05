# frozen_string_literal: true

# Demo Profile Seeds
# Creates narrative data profiles for compelling demos

puts "\n🎭 Creating Demo Profiles..."

# Clear existing demo tutors if they exist
demo_emails = [
  'sarah.excellence@demo.com',
  'james.improving@demo.com',
  'maria.declining@demo.com',
  'alex.churnrisk@demo.com'
]
Tutor.where(email: demo_emails).destroy_all

# Profile 1: STRONG TUTOR - Sarah Excellence
# High SQS, low FSRS, stable THS/TCRS - the gold standard
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
  
  session = Session.create!(
    tutor: sarah,
    student: student,
    scheduled_start_at: session_date,
    actual_start_at: session_date + rand(0..2).minutes, # Always on time
    scheduled_end_at: session_date + 1.hour,
    actual_end_at: session_date + 1.hour, # Full duration
    status: 'completed',
    tech_issue: false,
    first_session_for_student: (i == 0 && student == sarah_students.first)
  )
  
  # Excellent SQS scores (95-100)
  Score.create!(
    session: session,
    tutor: sarah,
    score_type: 'sqs',
    value: 95 + rand(0..5),
    components: {
      lateness_penalty: 0,
      duration_penalty: 0,
      tech_penalty: 0
    },
    computed_at: session_date
  )
  
  # Perfect first session if applicable
  if session.first_session_for_student
    SessionTranscript.create!(
      session: session,
      payload: {
        text: "Hi! I'm so glad to meet you. What are your goals for our sessions together? " \
              "That's a great goal! Let's work on that. You're doing excellent work here. " \
              "Great job on that problem! To summarize what we covered today, we worked on algebra fundamentals. " \
              "Next time, we'll build on this foundation. Keep up the great work!"
      }
    )
    
    Score.create!(
      session: session,
      tutor: sarah,
      score_type: 'fsrs',
      value: 0, # Perfect score
      components: {
        confusion_phrases: 0,
        negative_phrasing: 0,
        missing_goal_setting: 0,
        word_share_imbalance: 0,
        missing_encouragement: 0,
        missing_closing_summary: 0
      },
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

puts "    ✓ Sarah Excellence: 20 sessions, avg SQS: 98, FSRS: 0, THS: 95, TCRS: 0.15"

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
    first_session_for_student: (i == 0 && student == james_students.first)
  )
  
  # Improving SQS scores: 65->70->75->80->85
  base_score = 65 + (i * 1.5)
  sqs = [base_score + rand(-3..3), 100].min
  
  Score.create!(
    session: session,
    tutor: james,
    score_type: 'sqs',
    value: sqs.round(1),
    components: {
      lateness_penalty: lateness * 2,
      duration_penalty: duration_short,
      tech_penalty: session.tech_issue ? 10 : 0
    },
    computed_at: session_date
  )
  
  if session.first_session_for_student
    SessionTranscript.create!(
      session: session,
      payload: {
        text: "Hi there. Let's get started. What do you need help with? " \
              "Okay, let me explain this. You should focus on the basics first. " \
              "That's not quite right. Let me show you. " \
              "Great, you're getting it now! Let's do another problem."
      }
    )
    
    Score.create!(
      session: session,
      tutor: james,
      score_type: 'fsrs',
      value: 35, # Some issues but not terrible
      components: {
        confusion_phrases: 0,
        negative_phrasing: 2,
        missing_goal_setting: 1,
        word_share_imbalance: 0,
        missing_encouragement: 0,
        missing_closing_summary: 1
      },
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

puts "    ✓ James Improving: 15 sessions, SQS trend: 65→85, FSRS: 35, THS: 72, TCRS: 0.35"

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
    first_session_for_student: (i == 2 && student == maria_students[0])
  )
  
  # Declining SQS scores: 88->82->76->70->64
  base_score = 88 - (i * 1.6)
  sqs = [base_score + rand(-2..2), 0].max
  
  Score.create!(
    session: session,
    tutor: maria,
    score_type: 'sqs',
    value: sqs.round(1),
    components: {
      lateness_penalty: lateness * 2,
      duration_penalty: duration_short,
      tech_penalty: session.tech_issue ? 10 : 0
    },
    computed_at: session_date
  )
  
  if session.first_session_for_student
    SessionTranscript.create!(
      session: session,
      payload: {
        text: "Hi. Let's start. I'm not sure what you need help with. " \
              "This is confusing to explain. You should just memorize this. " \
              "I don't understand what you're asking. Let me think about that. " \
              "Okay, we're out of time. See you next week."
      }
    )
    
    Score.create!(
      session: session,
      tutor: maria,
      score_type: 'fsrs',
      value: 55, # High risk
      components: {
        confusion_phrases: 2,
        negative_phrasing: 1,
        missing_goal_setting: 1,
        word_share_imbalance: 1,
        missing_encouragement: 1,
        missing_closing_summary: 1
      },
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
  alert_type: 'poor_first_session',
  severity: 'high',
  status: 'open',
  triggered_at: 1.day.ago,
  metadata: {
    score_value: 55,
    score_computed_at: 1.day.ago,
    score_components: {
      confusion_phrases: 2,
      negative_phrasing: 1
    }
  }
)

puts "    ✓ Maria Declining: 15 sessions, SQS trend: 88→64, FSRS: 55 (ALERT), THS: 48, TCRS: 0.52"

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
    first_session_for_student: (i == 0)
  )
  
  # Mediocre, inconsistent SQS scores
  sqs = rand(60..75)
  
  Score.create!(
    session: session,
    tutor: alex,
    score_type: 'sqs',
    value: sqs,
    components: {
      lateness_penalty: lateness * 2,
      duration_penalty: duration_short,
      tech_penalty: session.tech_issue ? 10 : 0
    },
    computed_at: session_date
  )
  
  if session.first_session_for_student
    SessionTranscript.create!(
      session: session,
      payload: {
        text: "Hey. What do you want to work on today? " \
              "I'm not sure about that. This is confusing. " \
              "You should probably review this on your own. " \
              "Okay, I have to go. Bye."
      }
    )
    
    Score.create!(
      session: session,
      tutor: alex,
      score_type: 'fsrs',
      value: 45,
      components: {
        confusion_phrases: 1,
        negative_phrasing: 1,
        missing_goal_setting: 1,
        word_share_imbalance: 0,
        missing_encouragement: 1,
        missing_closing_summary: 1
      },
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

puts "    ✓ Alex ChurnRisk: 8 sessions, SQS: 68 avg, FSRS: 45, THS: 52, TCRS: 0.72 (2 ALERTS)"

puts "\n✅ Demo Profiles Created Successfully!"
puts "\nDemo Tutor IDs:"
puts "  Sarah Excellence (Strong): #{sarah.id}"
puts "  James Improving: #{james.id}"
puts "  Maria Declining: #{maria.id}"
puts "  Alex ChurnRisk: #{alex.id}"
puts "\nAccess dashboards at:"
puts "  Tutor: http://localhost:3000/tutor/[ID]"
puts "  Admin: http://localhost:3000/admin/1"

