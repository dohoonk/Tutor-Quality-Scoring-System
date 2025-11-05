# Task List (Concise, PR-Sized)

## EPIC 1 — Project Setup
- [ ] Create Rails app (`rails new tutor-insights --database=postgresql --css=tailwind`)
- [ ] Configure Postgres & run `db:create db:migrate`
- [ ] Add dotenv-rails for env mgmt

- [ ] Add Vite + React (`bundle add vite_rails && rails vite:install`)
- [ ] Confirm React mounts to `/tutor/:id` and `/admin/:id`

- [ ] Add Sidekiq + Redis
- [ ] Set `queue_adapter = :sidekiq`
- [ ] Mount Sidekiq dashboard route
- [ ] Add sidekiq-scheduler gem for scheduled jobs

---

## EPIC 2 — Models & Schema
- [ ] Create Tutor model
- [ ] Create Student model
- [ ] Create Session model with fields:
  - [ ] scheduled_start_at
  - [ ] actual_start_at
  - [ ] scheduled_end_at
  - [ ] actual_end_at
  - [ ] status
  - [ ] reschedule_initiator
  - [ ] tech_issue
  - [ ] first_session_for_student
- [ ] Add indexes for tutor_id + student_id

- [ ] Create SessionTranscript model (session_id, payload:jsonb)

- [ ] Create tables:
  - [ ] scores (session_id, score_type, value, components:jsonb, computed_at)
  - [ ] alerts (tutor_id, alert_type, severity, status, triggered_at, resolved_at, metadata:jsonb)
  - [ ] tutor_daily_aggregates (tutor_id, date, sessions_completed, reschedules_tutor_initiated, no_shows, avg_lateness_min, etc.)
  - [ ] tutor_churn_scores (tutor_id, tcrs_value, computed_at, components:jsonb) - optional table for caching

- [ ] Create materialized views:
  - [ ] tutor_stats_7d (rolling 7-day window for THS)
  - [ ] tutor_stats_14d (rolling 14-day window for TCRS)
- [ ] Add refresh functions for materialized views

---

## EPIC 3 — Seed Data Early
- [ ] Create seed tutors (10)
- [ ] Create seed students (20)
- [ ] Generate ~150 sessions (mixed statuses)
- [ ] Set first_session_for_student correctly

- [ ] Add ~20 mock transcript payloads (with speaker diarization)
- [ ] Create `rails db:reset && rails db:seed` script

---

## EPIC 4 — Scoring Services
### SQS (Session Quality Score)
- [ ] Compute lateness penalty: `min(20, 2 * lateness_min)`
- [ ] Compute duration shortfall penalty: `min(10, 1 * end_shortfall_min)`
- [ ] Compute tech disruption penalty: `10 if tech_issue else 0`
- [ ] Calculate final SQS: `clamp(0, 100, base - penalties)`
- [ ] Apply label thresholds (risk <60, warn 60-75, ok >75)
- [ ] Write score to `scores` table with components breakdown

### FSRS (First Session Risk Score)
- [ ] Detect confusion phrases (>=3 instances in student turns) → +20
- [ ] Compute tutor vs student word share (tutor >75% of words) → +20
- [ ] Detect missing goal-setting question early in session → +25
- [ ] Detect missing encouragement phrases → +15
- [ ] Detect negative phrasing streak → +10
- [ ] Detect missing closing summary or next steps → +20
- [ ] Apply tech/lateness disruption penalty → +10 if present
- [ ] Calculate final FSRS (sum of risk points)
- [ ] Generate structured feedback payload:
  - [ ] "What went well" (positive signals)
  - [ ] "One improvement idea" (highest-impact issue)
  - [ ] Breakdown by component
- [ ] Write FSRS to `scores` table (only for first_session_for_student = true)
- [ ] Skip FSRS if transcript lacks speaker diarization

### Alert Generation
- [ ] Create AlertService to evaluate triggers:
  - [ ] FSRS ≥ 50 → "Poor first session" alert
  - [ ] THS < 55 → "High reliability risk" alert
  - [ ] TCRS ≥ 0.6 → "Churn risk" alert
- [ ] Create AlertJob to run every 10 min
- [ ] Generate alerts in `alerts` table
- [ ] Auto-resolve alerts when conditions improve

---

## EPIC 5 — Tutor Dashboard (`/tutor/:id`)
- [ ] Create React route `/tutor/:id`

### API Endpoints
- [ ] `GET /api/tutor/:id/fsrs_latest` - Most recent FSRS with feedback
- [ ] `GET /api/tutor/:id/fsrs_history` - Last 5 first-sessions with FSRS
- [ ] `GET /api/tutor/:id/performance_summary` - AI-generated summary (template-based for MVP)
- [ ] `GET /api/tutor/:id/session_list` - Recent sessions with SQS values

### FSRS Feedback Section (top)
- [ ] Fetch most recent FSRS via `/api/tutor/:id/fsrs_latest`
- [ ] Display "First Session Quality Feedback" card:
  - [ ] SQS + FSRS indicators (visually separated)
  - [ ] "What went well" section
  - [ ] "One improvement idea" section
- [ ] FSRS Trend component:
  - [ ] Fetch FSRS history via `/api/tutor/:id/fsrs_history`
  - [ ] Display sparkline chart (last 5 first-sessions)
  - [ ] Show average FSRS score
  - [ ] Highlight improvement direction (e.g., +12% vs previous period)
- [ ] "View Past First Sessions" link → side panel:
  - [ ] List of previous FSRS summary entries
  - [ ] Each entry expandable with transcript-based explanation snippets

### Performance Summary Section (second)
- [ ] Fetch summary via `/api/tutor/:id/performance_summary`
- [ ] Display AI-generated text in UI
- [ ] Show SQS trend visualization

### Recent Sessions Table
- [ ] Fetch sessions via `/api/tutor/:id/session_list`
- [ ] Display table with: Date, Student, SQS, FSRS Tag, Notes

---

## EPIC 6 — Admin Dashboard (`/admin/:id`)
- [ ] Create React route `/admin/:id`

### API Endpoints
- [ ] `GET /api/admin/tutors/risk_list` - Sorted list with FSRS + THS + TCRS
- [ ] `GET /api/admin/tutor/:id/metrics` - Full metrics breakdown
- [ ] `GET /api/admin/tutor/:id/fsrs_history` - FSRS history for tutor
- [ ] `GET /api/admin/tutor/:id/intervention_log` - Past interventions
- [ ] `POST /api/admin/alerts/:id/update_status` - Update alert status

### Risk Overview Table
- [ ] Fetch tutors via `/api/admin/tutors/risk_list`
- [ ] Sort by risk (Reschedule, No-Show, Churn)
- [ ] Display: Tutor Name, Status Badges, FSRS, THS, TCRS, Alert Status

### Tutor Detail Panel
- [ ] Header: Tutor Name + Status Badges (Risk / Reliability / Churn)
- [ ] SQS Trend: Sparkline of last N sessions
- [ ] FSRS Overview: Last first-session score + Trend across students
- [ ] THS Breakdown (7-day Health Score):
  - [ ] Reschedule Rate (7d)
  - [ ] Lateness Trend (7d) - only behavioral patterns
  - [ ] No-Show Count (7d)
  - [ ] Overall THS value with label
- [ ] TCRS Breakdown (14-day Churn Risk):
  - [ ] Sessions_14d vs previous 14d
  - [ ] Availability_14d trend
  - [ ] Repeat Student Rate
  - [ ] Overall TCRS value with label
- [ ] Session Table: Date, Student, SQS, FSRS Tag, Notes
- [ ] First-Session Feedback List: Each FSRS case with transcript link + suggestions

### Alerts Management
- [ ] Fetch alerts for tutor
- [ ] Display alerts list with status
- [ ] Status update button (assign coach, mark outreach done, add note)
- [ ] Log interventions to intervention_log

---

## EPIC 7 — Reliability & Churn Jobs
### Daily Aggregation Job
- [ ] Create TutorDailyAggregationJob
- [ ] Compute tutor_daily_aggregates for completed sessions
- [ ] Calculate: sessions_completed, reschedules_tutor_initiated, no_shows, avg_lateness_min
- [ ] Schedule: every 10 minutes
- [ ] Refresh tutor_stats_7d materialized view after aggregation

### THS (Tutor Health Score) Job
- [ ] Create TutorHealthScoreJob
- [ ] Compute from tutor_stats_7d:
  - [ ] Tutor-initiated reschedule rate (7d)
  - [ ] No-show count (7d)
  - [ ] Behavioral lateness trend (only repeated patterns)
  - [ ] Quality recovery signals from recent sessions
- [ ] Calculate THS score (0-100)
- [ ] Apply label thresholds (<55 = high risk, 55-75 = monitor, >75 = stable)
- [ ] Write to scores table
- [ ] Schedule: every 10 minutes (after aggregation)

### TCRS (Tutor Churn Risk Score) Job
- [ ] Create TutorChurnRiskScoreJob
- [ ] Compute from tutor_stats_14d:
  - [ ] Availability drop vs previous 14d period
  - [ ] Completed sessions drop significantly
  - [ ] Tutor-initiated reschedules rise
  - [ ] Any no-shows in 14d window
  - [ ] Repeat student rate (14d)
- [ ] Calculate TCRS score (0-1 scale)
- [ ] Apply thresholds (≥0.6 = Support Check-In, 0.3-0.59 = Monitor, <0.3 = Stable)
- [ ] Optionally cache in tutor_churn_scores table
- [ ] Refresh tutor_stats_14d materialized view
- [ ] Schedule: every 10 minutes (after aggregation)

### Scoring Job
- [ ] Create SessionScoringJob
- [ ] Poll for new/updated sessions (DB polling every 5 min)
- [ ] Compute SQS for all completed sessions
- [ ] Compute FSRS for first_session_for_student = true (if transcript available)
- [ ] Write scores to scores table
- [ ] Schedule: every 5 minutes

### Job Scheduling Configuration
- [ ] Configure sidekiq-scheduler
- [ ] Set up recurring jobs:
  - [ ] SessionScoringJob: every 5 min
  - [ ] TutorDailyAggregationJob: every 10 min
  - [ ] TutorHealthScoreJob: every 10 min (after aggregation)
  - [ ] TutorChurnRiskScoreJob: every 10 min (after aggregation)
  - [ ] AlertJob: every 10 min

---

## EPIC 8 — Performance Summary Generation
- [ ] Create PerformanceSummaryService
- [ ] Template-based approach for MVP:
  - [ ] Analyze recent SQS trends
  - [ ] Identify patterns (improving, declining, stable)
  - [ ] Generate encouraging, supportive text
  - [ ] Highlight "What went well" and "One improvement suggestion"
- [ ] Cache summary for tutor (refresh daily)
- [ ] API endpoint: `GET /api/tutor/:id/performance_summary`

---

## EPIC 9 — Demo Polish
- [ ] Create narrative data profiles:
  - [ ] Strong tutor (high SQS, low FSRS, stable THS/TCRS)
  - [ ] Improving tutor (positive trend)
  - [ ] Slipping tutor (declining metrics)
  - [ ] Churn-risk tutor (high TCRS, low engagement)
- [ ] Prepare demo walk-through steps
- [ ] Document demo scenarios
