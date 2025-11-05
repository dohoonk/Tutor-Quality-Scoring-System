# Epic 11: FSRS → FSQS Refactor - Testing Checklist

## ✅ Pre-Testing Setup

### 1. Run Migration
```bash
bin/rails db:migrate
```

This will:
- Convert all existing `fsrs` scores to `fsqs`
- Update score_type in database
- Convert values from 0-120 scale to 0-100 scale
- Formula: `new_score = 100 * (1 - old_score/120)`

### 2. Verify Migration
```bash
bin/rails console
load 'tmp/test_fsqs_refactor.rb'
```

Expected results:
- ✅ All FSRS scores converted to FSQS
- ✅ Scores in 0-100 range
- ✅ Alert triggers at ≤50
- ✅ New service calculates correctly

---

## 🧪 Automated Testing

### Run Full Test Suite
```bash
bundle exec rspec
```

### Expected Test Results:
- **Service specs**: FirstSessionQualityScoreService
- **Job specs**: SessionScoringJob, AlertJob
- **Request specs**: API endpoints (fsqs_latest, fsqs_history)
- **Mailer specs**: low_first_session_quality_alert
- **Alert specs**: Threshold inversions

### If Tests Fail:
Common issues to check:
1. Score expectations might need manual adjustment (inverted thresholds)
2. API endpoint names updated everywhere
3. Alert type changed to `low_first_session_quality`

---

## 🔍 Manual Testing Checklist

### Backend Testing

#### 1. Score Calculation
```bash
bin/rails console

# Find a first session
session = Session.where(first_session_for_student: true)
                 .joins(:session_transcript)
                 .first

# Calculate FSQS
service = FirstSessionQualityScoreService.new(session)
result = service.calculate

puts "Score: #{result[:score]}/100 (higher is better)"
puts "Components: #{result[:components]}"
```

**Expected**: Score between 0-100, higher values for good sessions

#### 2. Alert Thresholds
```bash
bin/rails console

tutor = Tutor.first

# Create low quality score (should trigger alert)
Score.create!(
  tutor: tutor,
  session: Session.where(tutor: tutor, first_session_for_student: true).first,
  score_type: 'fsqs',
  value: 40.0,  # Low quality (≤50 triggers alert)
  components: {},
  computed_at: Time.current
)

# Run alert evaluation
AlertService.new.evaluate_and_create_alerts(tutor)

# Check alert
Alert.where(
  tutor: tutor,
  alert_type: 'low_first_session_quality',
  status: 'open'
).last
```

**Expected**: Alert created for FSQS ≤ 50

#### 3. API Endpoints
```bash
# Start server
bin/rails server

# In another terminal:
curl http://localhost:3000/api/tutor/1/fsqs_latest | jq
curl http://localhost:3000/api/tutor/1/fsqs_history | jq
curl http://localhost:3000/api/admin/tutors/risk_list | jq
```

**Expected**:
- fsqs_latest returns most recent FSQS
- fsqs_history returns last 5 first sessions
- risk_list includes fsqs field

---

### Frontend Testing

#### 1. Tutor Dashboard (`/tutor/1`)
- [ ] FSQS Score displays (0-100)
- [ ] Color coding correct:
  - ≤50 = Red (Low Quality)
  - ≤70 = Yellow (Fair)
  - \>70 = Green (Good)
- [ ] Tooltips say "Quality Score" (higher is better)
- [ ] Trend indicators work:
  - ↑ = Improving (green)
  - ↓ = Declining (red)
- [ ] Average FSQS calculated correctly
- [ ] Session table shows FSQS tags
- [ ] Past sessions panel displays FSQS

#### 2. Admin Dashboard (`/admin/1`)
- [ ] Risk list displays FSQS column
- [ ] Sorting by FSQS works
- [ ] Risk badges show for low FSQS (≤50)
- [ ] Tutor detail panel shows FSQS
- [ ] Color coding correct (inverted thresholds)

---

## 📧 Email Testing

### Trigger Email
```bash
bin/rails console

tutor = Tutor.first
alert = Alert.where(alert_type: 'low_first_session_quality').last

# Send email (opens in browser with letter_opener)
AlertMailer.low_first_session_quality_alert(alert, 'test@example.com').deliver_now
```

**Check**:
- [ ] Subject: "Low First Session Quality Detected"
- [ ] Body says "Quality Score" not "Risk Score"
- [ ] Score shows "X / 100 (Higher = Better Quality)"
- [ ] Recommendations are clear

---

## ✅ Verification Checklist

### Database
- [ ] All scores have `score_type = 'fsqs'`
- [ ] No scores with `score_type = 'fsrs'`
- [ ] Score values are 0-100
- [ ] Old alerts migrated to new type

### Code
- [ ] No references to `FirstSessionRiskScoreService`
- [ ] No references to `poor_first_session`
- [ ] All API routes use `fsqs_`
- [ ] Frontend uses `fsqs` variables

### Documentation
- [ ] All docs updated (9 files)
- [ ] API docs reflect new endpoints
- [ ] README accurate (if applicable)

---

## 🐛 Troubleshooting

### Issue: Tests failing with "unknown score_type 'fsqs'"
**Solution**: Run migration first (`bin/rails db:migrate`)

### Issue: Frontend shows "No FSQS score found"
**Solution**: 
1. Check API endpoint is `/fsqs_latest` not `/fsrs_latest`
2. Verify database has scores with `score_type = 'fsqs'`

### Issue: Alerts not triggering
**Solution**: 
1. Check threshold logic: `value <= 50` (not `>= 50`)
2. Verify alert_type is `low_first_session_quality`

### Issue: Email templates not found
**Solution**: 
1. Check `app/views/alert_mailer/low_first_session_quality_alert.*` files exist
2. Verify old `poor_first_session_alert.*` files removed

---

## 📊 Success Criteria

✅ **Migration Complete**:
- All FSRS scores converted to FSQS
- Values properly inverted (0-120 → 0-100)

✅ **Tests Pass**:
- All RSpec tests green
- No references to old naming

✅ **Frontend Works**:
- Dashboards display FSQS correctly
- Color coding uses inverted thresholds
- Tooltips explain "higher is better"

✅ **Backend Works**:
- API endpoints return FSQS data
- Alerts trigger at correct thresholds
- Emails use new templates

✅ **Documentation Updated**:
- All docs reflect FSQS
- API documentation accurate
- No FSRS references remain

---

## 🎉 Post-Verification

Once all checks pass:
1. ✅ Mark Task 11.9 complete
2. ✅ Close Epic 11
3. ✅ Celebrate the refactor! 🎊

The system now has:
- Consistent scoring (SQS and FSQS both higher-is-better)
- Clear naming (Quality vs Risk)
- Better UX (intuitive score interpretation)

