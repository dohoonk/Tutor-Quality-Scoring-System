# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding database..."

# Create 10 tutors
tutor_names = [
  "Alice Johnson",
  "Bob Smith",
  "Carol Williams",
  "David Brown",
  "Emma Davis",
  "Frank Miller",
  "Grace Wilson",
  "Henry Moore",
  "Ivy Taylor",
  "Jack Anderson"
]

tutors = tutor_names.map do |name|
  email = "#{name.downcase.gsub(' ', '.')}@example.com"
  Tutor.find_or_create_by!(email: email) do |tutor|
    tutor.name = name
  end
end

puts "✅ Created #{tutors.count} tutors"

# Create 20 students
student_names = [
  "Sarah Chen",
  "Michael Rodriguez",
  "Jessica Lee",
  "Christopher Kim",
  "Amanda Patel",
  "Ryan O'Connor",
  "Lauren Martinez",
  "Daniel Nguyen",
  "Olivia Thompson",
  "James Garcia",
  "Sophia White",
  "Matthew Harris",
  "Emily Jackson",
  "Andrew Martin",
  "Isabella Lewis",
  "Joshua Walker",
  "Mia Hall",
  "Benjamin Young",
  "Charlotte King",
  "Lucas Wright"
]

students = student_names.map do |name|
  email = "#{name.downcase.gsub(' ', '.')}@student.example.com"
  Student.find_or_create_by!(email: email) do |student|
    student.name = name
  end
end

puts "✅ Created #{students.count} students"

# Generate ~150 sessions with mixed statuses
# We'll distribute sessions across the last 30 days
session_count = 0
statuses = ['completed', 'completed', 'completed', 'cancelled', 'no_show', 'rescheduled']
reschedule_initiators = ['tutor', 'student', nil]

(0..29).each do |days_ago|
  date = Date.current - days_ago.days
  
  # Generate 4-6 sessions per day
  sessions_per_day = rand(4..6)
  
  sessions_per_day.times do
    tutor = tutors.sample
    student = students.sample
    
    scheduled_start = date.beginning_of_day + rand(9..17).hours + rand(0..59).minutes
    status = statuses.sample
    
    case status
    when 'completed'
      actual_start = scheduled_start + rand(0..15).minutes # 0-15 min late
      scheduled_end = scheduled_start + 1.hour
      actual_end = scheduled_end - rand(0..10).minutes # 0-10 min early
      reschedule_initiator = nil
      tech_issue = rand(1..100) <= 5 # 5% chance of tech issue
    when 'cancelled'
      actual_start = nil
      scheduled_end = scheduled_start + 1.hour
      actual_end = nil
      reschedule_initiator = reschedule_initiators.sample
      tech_issue = false
    when 'no_show'
      actual_start = nil
      scheduled_end = scheduled_start + 1.hour
      actual_end = nil
      reschedule_initiator = nil
      tech_issue = false
    when 'rescheduled'
      actual_start = nil
      scheduled_end = scheduled_start + 1.hour
      actual_end = nil
      reschedule_initiator = reschedule_initiators.sample
      tech_issue = false
    end
    
    Session.find_or_create_by!(
      tutor: tutor,
      student: student,
      scheduled_start_at: scheduled_start
    ) do |session|
      session.actual_start_at = actual_start
      session.scheduled_end_at = scheduled_end
      session.actual_end_at = actual_end
      session.status = status
      session.reschedule_initiator = reschedule_initiator
      session.tech_issue = tech_issue
      session.first_session_for_student = false # Will be set correctly below
    end
    
    session_count += 1
  end
end

puts "✅ Created #{session_count} sessions"

# Set first_session_for_student correctly
# For each student-tutor pair, mark the earliest session as first_session_for_student
tutors.each do |tutor|
  students.each do |student|
    sessions = Session.where(tutor: tutor, student: student).order(:scheduled_start_at)
    if sessions.any?
      # Mark the first session as first_session_for_student
      first_session = sessions.first
      first_session.update!(first_session_for_student: true)
      # Ensure all other sessions are marked as false
      sessions.where.not(id: first_session.id).update_all(first_session_for_student: false)
    end
  end
end

puts "✅ Set first_session_for_student flags correctly"

# Add ~20 mock transcript payloads (with speaker diarization)
# Only for completed first sessions
transcript_sessions = Session.where(status: 'completed', first_session_for_student: true).limit(20)

transcript_sessions.each do |session|
  next if SessionTranscript.exists?(session: session)
  
  # Generate mock transcript with speaker diarization
  transcript_payload = {
    'speakers' => [
      {
        'speaker' => 'tutor',
        'text' => 'Hello! Welcome to your first session. How are you doing today?',
        'timestamp' => '00:00:01',
        'words' => 12
      },
      {
        'speaker' => 'student',
        'text' => 'Hi, I am doing well, thank you! I am excited to start learning.',
        'timestamp' => '00:00:05',
        'words' => 13
      },
      {
        'speaker' => 'tutor',
        'text' => 'That is great to hear! What would you like to focus on today?',
        'timestamp' => '00:00:12',
        'words' => 10
      },
      {
        'speaker' => 'student',
        'text' => 'I want to improve my math skills, especially algebra.',
        'timestamp' => '00:00:18',
        'words' => 10
      },
      {
        'speaker' => 'tutor',
        'text' => 'Perfect! Let us start with some basic concepts and build from there.',
        'timestamp' => '00:00:25',
        'words' => 12
      }
    ],
    'metadata' => {
      'duration' => 3600,
      'language' => 'en',
      'total_words_tutor' => 150,
      'total_words_student' => 80
    }
  }
  
  SessionTranscript.create!(
    session: session,
    payload: transcript_payload
  )
end

puts "✅ Created #{transcript_sessions.count} session transcripts"

puts "🎉 Seeding complete!"
