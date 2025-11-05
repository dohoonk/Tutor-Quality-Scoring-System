# Debug script to understand what's happening in TutorHealthScoreJob

# Set up test data
tutor = Tutor.create!(name: 'Debug Tutor', email: 'debug@example.com')
puts "Created tutor: #{tutor.id}"

# Create aggregates
7.times do |i|
  agg = TutorDailyAggregate.create!(
    tutor: tutor,
    date: (i + 1).days.ago.to_date,
    sessions_completed: 3,
    reschedules_tutor_initiated: 0,
    no_shows: 0,
    avg_lateness_min: 0.0
  )
  puts "Created aggregate for #{agg.date}: #{agg.id}"
end

puts "\nQuerying aggregates for tutor #{tutor.id}:"
aggregates = TutorDailyAggregate
             .where(tutor_id: tutor.id)
             .where('date >= ?', 30.days.ago.to_date)
             .order(date: :desc)
             .take(7)
             
puts "Found #{aggregates.count} aggregates"
aggregates.each { |a| puts "  - #{a.date}: #{a.sessions_completed} sessions" }

puts "\nRunning job..."
begin
  TutorHealthScoreJob.new.perform
  puts "Job completed successfully"
rescue => e
  puts "Job failed: #{e.message}"
  puts e.backtrace.first(5)
end

puts "\nChecking for scores:"
scores = Score.where(tutor_id: tutor.id, score_type: 'ths')
puts "Found #{scores.count} THS scores"
scores.each { |s| puts "  - Value: #{s.value}, Computed at: #{s.computed_at}" }

# Cleanup
tutor.destroy

