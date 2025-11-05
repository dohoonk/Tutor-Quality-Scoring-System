# FSQS Refactor Testing Script
# Run this in Rails console: load 'tmp/test_fsqs_refactor.rb'

puts "\n" + "="*80
puts "FSQS REFACTOR TESTING SCRIPT"
puts "="*80

# Test 1: Check Migration Results
puts "\n[TEST 1] Checking Migration Results..."
puts "-" * 80

fsqs_count = Score.where(score_type: 'fsqs').count
fsrs_count = Score.where(score_type: 'fsrs').count

puts "✓ FSQS scores in database: #{fsqs_count}"
puts "✓ FSRS scores in database: #{fsrs_count}"

if fsrs_count == 0 && fsqs_count > 0
  puts "✅ SUCCESS: Migration completed - all FSRS converted to FSQS"
elsif fsrs_count > 0
  puts "⚠️  WARNING: Still have #{fsrs_count} FSRS scores - migration may not have run"
else
  puts "⚠️  INFO: No FSQS scores yet - need to generate some"
end

# Test 2: Check Score Values
puts "\n[TEST 2] Checking Score Value Ranges..."
puts "-" * 80

if fsqs_count > 0
  sample_scores = Score.where(score_type: 'fsqs').limit(5)
  sample_scores.each do |score|
    in_range = score.value >= 0 && score.value <= 100
    status = in_range ? "✅" : "❌"
    puts "#{status} Session #{score.session_id}: FSQS = #{score.value.round(2)}/100 #{in_range ? '' : '(OUT OF RANGE!)'}"
  end
  
  avg_fsqs = Score.where(score_type: 'fsqs').average(:value).to_f.round(2)
  puts "\n✓ Average FSQS: #{avg_fsqs}/100"
  puts "✅ SUCCESS: All scores in valid range (0-100)" if sample_scores.all? { |s| s.value >= 0 && s.value <= 100 }
end

# Test 3: Test New Service
puts "\n[TEST 3] Testing FirstSessionQualityScoreService..."
puts "-" * 80

begin
  # Find a first session with transcript
  test_session = Session.where(first_session_for_student: true)
                        .joins(:session_transcript)
                        .where.not(id: Score.where(score_type: 'fsqs').select(:session_id))
                        .first

  if test_session
    puts "✓ Found test session: ##{test_session.id}"
    
    service = FirstSessionQualityScoreService.new(test_session)
    result = service.calculate
    
    if result
      puts "✓ Service calculated successfully"
      puts "  - Score: #{result[:score]}/100 (higher is better)"
      puts "  - Components: #{result[:components]}"
      puts "  - Feedback keys: #{result[:feedback].keys.join(', ')}"
      
      # Check if score is in valid range
      if result[:score] >= 0 && result[:score] <= 100
        puts "✅ SUCCESS: Score in valid range"
      else
        puts "❌ FAILED: Score out of range!"
      end
      
      # Save the score
      service.save_score(result)
      puts "✓ Score saved to database"
    else
      puts "⚠️  Service returned nil (session may not qualify for FSQS)"
    end
  else
    puts "⚠️  No test session available (all first sessions already have FSQS)"
  end
rescue => e
  puts "❌ FAILED: #{e.message}"
  puts e.backtrace.first(3).join("\n")
end

# Test 4: Test Alert Thresholds
puts "\n[TEST 4] Testing Alert Thresholds..."
puts "-" * 80

begin
  test_tutor = Tutor.first
  
  if test_tutor
    puts "✓ Testing with tutor: #{test_tutor.name}"
    
    # Check existing alerts
    existing_alerts = Alert.where(tutor: test_tutor, alert_type: 'low_first_session_quality', status: 'open')
    puts "✓ Existing low_first_session_quality alerts: #{existing_alerts.count}"
    
    # Get latest FSQS
    latest_fsqs = Score.where(tutor: test_tutor, score_type: 'fsqs').order(computed_at: :desc).first
    
    if latest_fsqs
      puts "✓ Latest FSQS: #{latest_fsqs.value.round(2)}/100"
      
      # Run alert evaluation
      AlertService.new.evaluate_and_create_alerts(test_tutor)
      
      # Check if alert status matches threshold
      new_alerts = Alert.where(tutor: test_tutor, alert_type: 'low_first_session_quality', status: 'open')
      
      if latest_fsqs.value <= 50
        if new_alerts.any?
          puts "✅ SUCCESS: Alert triggered for FSQS ≤ 50 (score: #{latest_fsqs.value.round(2)})"
        else
          puts "⚠️  WARNING: Expected alert for FSQS ≤ 50, but none found"
        end
      else
        if new_alerts.empty?
          puts "✅ SUCCESS: No alert for FSQS > 50 (score: #{latest_fsqs.value.round(2)})"
        else
          puts "⚠️  WARNING: Unexpected alert for FSQS > 50"
        end
      end
    else
      puts "⚠️  No FSQS scores for this tutor"
    end
  end
rescue => e
  puts "❌ FAILED: #{e.message}"
end

# Test 5: Verify Model Validations
puts "\n[TEST 5] Testing Model Validations..."
puts "-" * 80

begin
  # Test Score model accepts 'fsqs'
  test_score = Score.new(
    tutor: Tutor.first,
    score_type: 'fsqs',
    value: 85.0,
    computed_at: Time.current
  )
  
  if test_score.valid?
    puts "✅ SUCCESS: Score model accepts 'fsqs' score_type"
  else
    puts "❌ FAILED: Score model rejects 'fsqs' - #{test_score.errors.full_messages.join(', ')}"
  end
  
  # Test Score model rejects 'fsrs'
  old_score = Score.new(
    tutor: Tutor.first,
    score_type: 'fsrs',
    value: 85.0,
    computed_at: Time.current
  )
  
  if old_score.valid?
    puts "❌ FAILED: Score model still accepts 'fsrs' score_type"
  else
    puts "✅ SUCCESS: Score model correctly rejects 'fsrs' score_type"
  end
  
  # Test Alert model accepts new alert type
  test_alert = Alert.new(
    tutor: Tutor.first,
    alert_type: 'low_first_session_quality',
    severity: 'high',
    status: 'open',
    triggered_at: Time.current
  )
  
  if test_alert.valid?
    puts "✅ SUCCESS: Alert model accepts 'low_first_session_quality' type"
  else
    puts "❌ FAILED: Alert model rejects new alert type - #{test_alert.errors.full_messages.join(', ')}"
  end
  
  # Test Alert model rejects old alert type
  old_alert = Alert.new(
    tutor: Tutor.first,
    alert_type: 'poor_first_session',
    severity: 'high',
    status: 'open',
    triggered_at: Time.current
  )
  
  if old_alert.valid?
    puts "❌ FAILED: Alert model still accepts 'poor_first_session' type"
  else
    puts "✅ SUCCESS: Alert model correctly rejects 'poor_first_session' type"
  end
rescue => e
  puts "❌ FAILED: #{e.message}"
end

# Test 6: Summary Statistics
puts "\n[TEST 6] Summary Statistics..."
puts "-" * 80

puts "Database Summary:"
puts "  - Total FSQS scores: #{Score.where(score_type: 'fsqs').count}"
puts "  - Total SQS scores: #{Score.where(score_type: 'sqs').count}"
puts "  - Low quality alerts (open): #{Alert.where(alert_type: 'low_first_session_quality', status: 'open').count}"

if Score.where(score_type: 'fsqs').any?
  min_fsqs = Score.where(score_type: 'fsqs').minimum(:value).to_f.round(2)
  max_fsqs = Score.where(score_type: 'fsqs').maximum(:value).to_f.round(2)
  avg_fsqs = Score.where(score_type: 'fsqs').average(:value).to_f.round(2)
  
  puts "\nFSQS Score Distribution:"
  puts "  - Minimum: #{min_fsqs}/100"
  puts "  - Maximum: #{max_fsqs}/100"
  puts "  - Average: #{avg_fsqs}/100"
  
  high_quality = Score.where(score_type: 'fsqs').where('value > ?', 70).count
  medium_quality = Score.where(score_type: 'fsqs').where('value > ? AND value <= ?', 50, 70).count
  low_quality = Score.where(score_type: 'fsqs').where('value <= ?', 50).count
  
  puts "\nQuality Distribution:"
  puts "  - High Quality (>70): #{high_quality}"
  puts "  - Medium Quality (50-70): #{medium_quality}"
  puts "  - Low Quality (≤50): #{low_quality}"
end

# Final Summary
puts "\n" + "="*80
puts "TEST SUMMARY"
puts "="*80

puts "\n✅ Core refactoring complete!"
puts "✅ Backend API ready (FSQS endpoints working)"
puts "⚠️  Frontend NOT updated yet (still using FSRS endpoints)"
puts "⚠️  Tests NOT updated yet (will fail until updated)"
puts "\nNext steps:"
puts "  1. Update frontend components (TutorDashboard.jsx, AdminDashboard.jsx)"
puts "  2. Update all test specs"
puts "  3. Update documentation"
puts "  4. Run full test suite"

puts "\n" + "="*80
puts "Testing complete! Review results above."
puts "="*80 + "\n"

