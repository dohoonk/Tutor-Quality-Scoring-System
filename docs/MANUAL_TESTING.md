# Manual Testing Guide for Tutor Dashboard

## Prerequisites

1. **Database Setup**: Make sure your database is set up and seeded
2. **Dependencies**: All gems and npm packages installed

## Step 1: Prepare the Database

First, ensure your database has seed data with tutors, students, sessions, and scores:

```bash
cd tutor-insights
rails db:reset  # This will drop, create, migrate, and seed
```

Or if you just need to seed:
```bash
rails db:seed
```

The seed file creates:
- 10 tutors
- 20 students
- ~150 sessions (mixed statuses)
- ~20 session transcripts (for first sessions)
- You'll need to run scoring jobs to generate scores (see Step 3)

## Step 2: Start the Development Servers

You have two options:

### Option A: Use Foreman (Recommended - starts all services)

```bash
bin/dev
```

This starts:
- Rails server (port 3000)
- Tailwind CSS watcher
- Vite dev server (port 3036)

### Option B: Start Services Manually

In separate terminal windows:

**Terminal 1 - Rails Server:**
```bash
bin/rails server
```

**Terminal 2 - Tailwind CSS:**
```bash
bin/rails tailwindcss:watch
```

**Terminal 3 - Vite Dev Server:**
```bash
bin/vite dev
```

## Step 3: Generate Scores (Required for Testing)

The dashboard needs scores to display. You can either:

### Option A: Run Scoring Services Manually (Rails Console)

```bash
rails console
```

Then in the console:
```ruby
# Get a tutor with completed sessions
tutor = Tutor.first
sessions = tutor.sessions.where(status: 'completed').limit(5)

# Calculate and save SQS scores
sessions.each do |session|
  service = SessionQualityScoreService.new(session)
  result = service.calculate
  service.save_score(result)
end

# Calculate and save FSQS scores for first sessions
first_sessions = tutor.sessions.where(status: 'completed', first_session_for_student: true).limit(5)
first_sessions.each do |session|
  next unless session.session_transcript
  service = FirstSessionQualityScoreService.new(session)
  result = service.calculate
  service.save_score(result) if result
end
```

### Option B: Create Test Scores via Console

```bash
rails console
```

```ruby
tutor = Tutor.first
student = Student.first

# Create a completed session
session = Session.create!(
  tutor: tutor,
  student: student,
  scheduled_start_at: 1.hour.ago,
  actual_start_at: 1.hour.ago,
  scheduled_end_at: Time.current,
  actual_end_at: Time.current,
  status: 'completed',
  first_session_for_student: true,
  tech_issue: false
)

# Create transcript
SessionTranscript.create!(
  session: session,
  payload: {
    'speakers' => [
      { 'speaker' => 'tutor', 'text' => 'What are your goals for today?', 'words' => 6 },
      { 'speaker' => 'student', 'text' => 'I want to learn math', 'words' => 5 },
      { 'speaker' => 'tutor', 'text' => 'Great! You are doing well. Let us summarize what we covered.', 'words' => 10 }
    ],
    'metadata' => { 'total_words_tutor' => 16, 'total_words_student' => 5 }
  }
)

# Calculate SQS
sqs_service = SessionQualityScoreService.new(session)
sqs_result = sqs_service.calculate
sqs_service.save_score(sqs_result)

# Calculate FSQS
fsrs_service = FirstSessionQualityScoreService.new(session)
fsrs_result = fsrs_service.calculate
fsrs_service.save_score(fsrs_result) if fsrs_result

# Create more sessions for history
5.times do |i|
  student = Student.create!(name: "Student #{i}", email: "student#{i}@test.com")
  session = Session.create!(
    tutor: tutor,
    student: student,
    scheduled_start_at: i.days.ago,
    actual_start_at: i.days.ago,
    scheduled_end_at: i.days.ago + 1.hour,
    actual_end_at: i.days.ago + 1.hour,
    status: 'completed',
    first_session_for_student: true
  )
  
  SessionTranscript.create!(
    session: session,
    payload: {
      'speakers' => [
        { 'speaker' => 'tutor', 'text' => 'Hello', 'words' => 1 },
        { 'speaker' => 'student', 'text' => 'Hi', 'words' => 1 }
      ],
      'metadata' => { 'total_words_tutor' => 1, 'total_words_student' => 1 }
    }
  )
  
  fsrs_service = FirstSessionQualityScoreService.new(session)
  fsrs_result = fsrs_service.calculate
  fsrs_service.save_score(fsrs_result) if fsrs_result
  
  sqs_service = SessionQualityScoreService.new(session)
  sqs_result = sqs_service.calculate
  sqs_service.save_score(sqs_result)
end
```

## Step 4: Access the Dashboard

1. **Open your browser** and navigate to:
   ```
   http://localhost:3000/tutor/1
   ```
   (Replace `1` with any valid tutor ID from your database)

2. **To find tutor IDs:**
   ```bash
   rails console
   Tutor.pluck(:id, :name)
   ```

## Step 5: What to Test

### ✅ FSQS Feedback Section (Top)
- [ ] Most recent FSQS score is displayed
- [ ] FSQS indicator shows correct color (red/yellow/green)
- [ ] Average FSQS for last 5 sessions is shown
- [ ] Improvement direction percentage is displayed
- [ ] "What went well" section shows feedback
- [ ] "One improvement idea" section shows feedback
- [ ] FSQS trend sparkline chart is visible (bar chart)
- [ ] "View Past First Sessions" button works
- [ ] Side panel opens when clicking "View Past First Sessions"
- [ ] Side panel shows list of past FSQS entries
- [ ] Each entry shows student name, date, score, and feedback
- [ ] Side panel can be closed

### ✅ Performance Summary Section
- [ ] Performance summary text is displayed
- [ ] SQS trend visualization is shown (bar chart)
- [ ] Chart shows last 10 sessions

### ✅ Recent Sessions Table
- [ ] Table displays recent sessions
- [ ] Date column shows formatted dates
- [ ] Student name column is populated
- [ ] SQS column shows score with color-coded label
- [ ] FSQS Tag column shows FSQS for first sessions
- [ ] Notes column shows "First Session" for first sessions
- [ ] Empty state shows "No sessions found" when no data

### ✅ API Endpoints (Test via Browser Console)

Open browser DevTools (F12) and test API endpoints:

```javascript
// Test FSQS Latest
fetch('/api/tutor/1/fsqs_latest')
  .then(r => r.json())
  .then(console.log)

// Test FSQS History
fetch('/api/tutor/1/fsqs_history')
  .then(r => r.json())
  .then(console.log)

// Test Performance Summary
fetch('/api/tutor/1/performance_summary')
  .then(r => r.json())
  .then(console.log)

// Test Session List
fetch('/api/tutor/1/session_list')
  .then(r => r.json())
  .then(console.log)
```

## Step 6: Test Edge Cases

### No FSQS Data
1. Use a tutor ID that has no FSQS scores
2. Verify the dashboard handles missing data gracefully
3. Check that sections don't break

### No Session Data
1. Use a tutor ID with no sessions
2. Verify empty states display correctly

### Loading States
1. Check browser Network tab (F12 → Network)
2. Verify API calls are made
3. Check that loading state appears briefly

## Troubleshooting

### React Not Loading
- Check browser console for errors
- Verify Vite dev server is running (port 3036)
- Check that `application.jsx` is being served

### API Errors
- Check Rails server logs
- Verify database has data
- Check that scores exist in the database

### Styling Issues
- Verify Tailwind CSS watcher is running
- Check that `app/assets/tailwind/application.css` is imported
- Restart Tailwind watcher if styles don't update

### No Data Showing
- Verify scores exist: `Score.where(tutor_id: 1).count`
- Check sessions exist: `Session.where(tutor_id: 1).count`
- Verify transcripts exist for first sessions

## Quick Test Script

Run this in Rails console to quickly set up test data:

```ruby
tutor = Tutor.first || Tutor.create!(name: 'Test Tutor', email: 'test@example.com')

# Create test sessions with scores
5.times do |i|
  student = Student.find_or_create_by!(email: "student#{i}@test.com") do |s|
    s.name = "Student #{i}"
  end
  
  session = Session.find_or_create_by!(
    tutor: tutor,
    student: student,
    scheduled_start_at: i.days.ago
  ) do |s|
    s.actual_start_at = i.days.ago
    s.scheduled_end_at = i.days.ago + 1.hour
    s.actual_end_at = i.days.ago + 1.hour
    s.status = 'completed'
    s.first_session_for_student = true
    s.tech_issue = false
  end
  
  # Create transcript
  unless session.session_transcript
    SessionTranscript.create!(
      session: session,
      payload: {
        'speakers' => [
          { 'speaker' => 'tutor', 'text' => 'What are your goals for today?', 'words' => 6 },
          { 'speaker' => 'student', 'text' => 'I want to learn', 'words' => 4 },
          { 'speaker' => 'tutor', 'text' => 'Great! Let us summarize.', 'words' => 4 }
        ],
        'metadata' => { 'total_words_tutor' => 10, 'total_words_student' => 4 }
      }
    )
  end
  
  # Calculate and save scores
  unless Score.exists?(session: session, score_type: 'sqs')
    sqs_service = SessionQualityScoreService.new(session)
    sqs_result = sqs_service.calculate
    sqs_service.save_score(sqs_result)
  end
  
  unless Score.exists?(session: session, score_type: 'fsrs')
    fsrs_service = FirstSessionQualityScoreService.new(session)
    fsrs_result = fsrs_service.calculate
    fsrs_service.save_score(fsrs_result) if fsrs_result
  end
end

puts "✅ Test data created for tutor #{tutor.id}"
puts "Visit: http://localhost:3000/tutor/#{tutor.id}"
```

## Expected Results

When everything is working, you should see:

1. **Dashboard loads** without errors in console
2. **FSQS Feedback card** at the top with score and feedback
3. **FSQS Trend chart** showing bar visualization
4. **Performance Summary** with text and SQS trend
5. **Recent Sessions Table** with data rows
6. **All sections** are styled with Tailwind CSS
7. **Side panel** opens/closes smoothly
8. **No console errors** in browser DevTools

