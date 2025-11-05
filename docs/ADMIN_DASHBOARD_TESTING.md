# Admin Dashboard Manual Testing Guide

This guide will help you manually test the Admin Dashboard (EPIC 6) functionality.

## Prerequisites

1. **Ensure servers are running:**
   ```bash
   cd tutor-insights
   bin/dev
   ```
   This starts:
   - Rails server (port 3000)
   - Vite dev server (port 3036)
   - Tailwind CSS watcher
   - Sidekiq (background jobs)

2. **Ensure test data exists:**
   ```bash
   # If you haven't seeded data yet:
   rails db:seed
   ```

## Testing the Admin Dashboard UI

### Step 1: Access the Admin Dashboard

Open your browser and navigate to:
```
http://localhost:3000/admin/1
```

**Expected Result:**
- Page loads successfully
- You see "Admin Dashboard" as the title
- A "Tutor Risk Overview" table is displayed

### Step 2: Verify Risk Overview Table

The table should display:
- **Columns:** Tutor Name, Status, FSRS, THS, TCRS, Alerts, Actions
- **Multiple tutors** from the seed data
- **Color-coded status badges:**
  - Red badges = High risk
  - Yellow badges = Warning/Monitor
  - Green badges = Stable
- **Risk scores:**
  - FSRS values (0-100, lower is better)
  - THS values (0-100, higher is better)
  - TCRS values (0-1, lower is better)
- **Alert counts** (if any alerts exist)
- **"View Details" button** for each tutor

**What to check:**
- [ ] Table renders correctly
- [ ] All tutors from seed data appear
- [ ] Status badges show appropriate colors
- [ ] Scores display correctly (or "N/A" if no scores)
- [ ] Alert counts display correctly

### Step 3: Click "View Details" on a Tutor

Click the "View Details" button on any tutor in the table.

**Expected Result:**
- A new section appears below the table
- Shows "Tutor Details: [Tutor Name]"
- Displays three score cards:
  1. **First Session Risk Score (FSRS)**
     - Shows numeric score
     - Color-coded indicator (⚠️ High Risk / Warning / ✓ Good)
  2. **Tutor Health Score (THS) - 7d**
     - Shows numeric score
     - Color-coded indicator (⚠️ High Risk / Monitor / ✓ Stable)
  3. **Churn Risk Score (TCRS) - 14d**
     - Shows numeric score
     - Color-coded indicator (⚠️ High Risk / Monitor / ✓ Stable)

**What to check:**
- [ ] Detail panel opens correctly
- [ ] Tutor name displays in header
- [ ] All three score cards display
- [ ] Scores have correct color coding
- [ ] "✕ Close" button appears in top right

### Step 4: Verify Session Quality Trend (if available)

If the tutor has SQS scores, you should see:
- **"Session Quality Trend" section**
- A bar chart showing recent sessions
- Bars colored based on SQS:
  - Red = SQS < 60 (poor)
  - Yellow = SQS 60-75 (warning)
  - Green = SQS > 75 (good)
- Label showing "Last N sessions"

**What to check:**
- [ ] Chart displays correctly
- [ ] Bars are color-coded appropriately
- [ ] Hover shows session score
- [ ] Text indicates number of sessions

### Step 5: Verify Past Interventions (if available)

If the tutor has resolved alerts, you should see:
- **"Past Interventions" section**
- List of past alerts with:
  - Alert type (e.g., "Poor First Session", "High Reliability Risk")
  - Triggered date
  - Resolved date
  - Severity badge (High/Medium/Low)

**What to check:**
- [ ] Past interventions display correctly
- [ ] Dates are formatted properly
- [ ] Severity badges have correct colors

### Step 6: Close Detail Panel

Click the "✕ Close" button in the tutor detail panel.

**Expected Result:**
- Detail panel disappears
- You're back to the Risk Overview Table

**What to check:**
- [ ] Panel closes correctly
- [ ] Table remains visible and functional

### Step 7: Test Multiple Tutors

Repeat steps 3-6 for different tutors in the table.

**What to check:**
- [ ] Different tutors load correctly
- [ ] Scores vary appropriately
- [ ] UI remains responsive

## Testing the API Endpoints Directly

You can test the API endpoints using `curl` or your browser's developer tools.

### Test 1: Get Risk List

```bash
curl http://localhost:3000/api/admin/tutors/risk_list | jq
```

**Expected Response:**
```json
[
  {
    "id": 1,
    "name": "Alice Johnson",
    "email": "alice@example.com",
    "fsrs": 15.0,
    "ths": 85.5,
    "tcrs": 0.25,
    "alert_count": 0
  },
  ...
]
```

**What to check:**
- [ ] Returns array of tutors
- [ ] Each tutor has all required fields
- [ ] Scores are numbers or null
- [ ] Tutors are sorted by risk (highest risk first)

### Test 2: Get Tutor Metrics

```bash
curl http://localhost:3000/api/admin/tutor/1/metrics | jq
```

**Expected Response:**
```json
{
  "tutor_id": 1,
  "name": "Alice Johnson",
  "email": "alice@example.com",
  "fsrs": 15.0,
  "ths": 85.5,
  "tcrs": 0.25,
  "sqs_history": [
    {"date": "2025-11-04T...", "value": 95.0},
    ...
  ]
}
```

**What to check:**
- [ ] Returns tutor details
- [ ] Includes latest scores
- [ ] SQS history array present (if tutor has sessions)

### Test 3: Get FSRS History

```bash
curl http://localhost:3000/api/admin/tutor/1/fsrs_history | jq
```

**Expected Response:**
```json
[
  {
    "score": 15.0,
    "computed_at": "2025-11-04T...",
    "session_id": 303,
    "session_date": "2025-11-03T...",
    "student_name": "Student Name",
    "components": { "confusion_phrases": 0, ... }
  },
  ...
]
```

**What to check:**
- [ ] Returns array of FSRS scores
- [ ] Each has score, dates, and components
- [ ] Sorted by most recent first

### Test 4: Get Intervention Log

```bash
curl http://localhost:3000/api/admin/tutor/1/intervention_log | jq
```

**Expected Response:**
```json
[
  {
    "id": 1,
    "alert_type": "poor_first_session",
    "severity": "high",
    "triggered_at": "2025-11-01T...",
    "resolved_at": "2025-11-02T...",
    "metadata": { ... }
  },
  ...
]
```

**What to check:**
- [ ] Returns array of resolved alerts
- [ ] Each has type, severity, dates
- [ ] Sorted by most recent first

### Test 5: Update Alert Status

```bash
curl -X POST http://localhost:3000/api/admin/alerts/1/update_status \
  -H "Content-Type: application/json" \
  -d '{"status": "acknowledged", "notes": "Following up with tutor"}' | jq
```

**Expected Response:**
```json
{
  "id": 1,
  "status": "acknowledged",
  "resolved_at": null,
  "metadata": {
    "notes": [
      {
        "text": "Following up with tutor",
        "added_at": "2025-11-05T...",
        "added_by": "admin"
      }
    ]
  }
}
```

**What to check:**
- [ ] Status updates correctly
- [ ] Notes are added to metadata
- [ ] Response includes updated alert

## Testing Background Jobs Integration

### Verify SessionScoringJob is Running

Check Sidekiq logs in your terminal (where `bin/dev` is running):

**Expected:**
- You should see log entries every 5 minutes like:
  ```
  SessionScoringJob: Processing...
  ```

### Verify AlertJob is Running

**Expected:**
- You should see log entries every 10 minutes like:
  ```
  AlertJob: Processing...
  ```

### Monitor Sidekiq Dashboard

Visit:
```
http://localhost:3000/sidekiq
```

**What to check:**
- [ ] Sidekiq dashboard loads
- [ ] Shows scheduled jobs
- [ ] Shows processed job counts
- [ ] No failed jobs (or investigate if there are failures)

## Common Issues and Troubleshooting

### Issue: No tutors appear in the table
**Solution:**
```bash
rails db:seed
```
Run the seed script to create test data.

### Issue: Scores show as "N/A"
**Solution:**
This is expected if SessionScoringJob hasn't run yet. Either:
1. Wait 5-10 minutes for jobs to run automatically
2. Manually trigger the job:
   ```bash
   rails console
   SessionScoringJob.new.perform
   exit
   ```

### Issue: React component not loading
**Solution:**
1. Check browser console for errors
2. Ensure Vite dev server is running (part of `bin/dev`)
3. Hard refresh: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows/Linux)

### Issue: API returns 404
**Solution:**
1. Check that Rails server is running on port 3000
2. Verify the route exists:
   ```bash
   rails routes | grep admin
   ```

### Issue: Sidekiq jobs not running
**Solution:**
1. Check Redis is running:
   ```bash
   redis-cli ping
   # Should return: PONG
   ```
2. Restart `bin/dev` to restart all services

## Success Criteria

✅ **Admin Dashboard is working correctly if:**
- Risk Overview Table displays all tutors
- Status badges show appropriate risk levels
- Clicking "View Details" shows tutor metrics
- Score cards display correctly with color coding
- API endpoints return valid JSON responses
- Background jobs are scheduled and running
- No errors in browser console or terminal logs

## Next Steps

After confirming the Admin Dashboard works:
1. Test different tutors to see variety in risk levels
2. Wait for background jobs to process and generate new scores
3. Verify alerts are created when thresholds are exceeded
4. Test the alert update functionality
5. Move on to testing the complete end-to-end workflow

---

**Need Help?**
- Check browser console (F12) for JavaScript errors
- Check Rails server logs for API errors
- Check Sidekiq logs for background job errors
- Review the test data in `db/seeds.rb`

