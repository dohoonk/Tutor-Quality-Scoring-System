# Task List (Concise, PR-Sized)

## EPIC 1 — Project Setup
- [x] Create Rails app (`rails new tutor-insights --database=postgresql --css=tailwind`)
- [x] Configure Postgres & run `db:create db:migrate`
- [x] Add dotenv-rails for env mgmt

- [x] Add Vite + React (`bundle add vite_rails && rails vite:install`)
- [x] Confirm React mounts to `/tutor/:id` and `/admin/:id`

- [x] Add Sidekiq + Redis
- [x] Set `queue_adapter = :sidekiq`
- [x] Mount Sidekiq dashboard route
- [x] Add sidekiq-scheduler gem for scheduled jobs

---

## EPIC 2 — Models & Schema (TDD Approach)
- [x] Set up RSpec for testing
- [x] Create Tutor model (TDD: write test → see fail → build model → see pass)
- [x] Create Student model (TDD: write test → see fail → build model → see pass)
- [x] Create Session model (TDD: write test → see fail → build model → see pass) with fields:
  - [x] scheduled_start_at
  - [x] actual_start_at
  - [x] scheduled_end_at
  - [x] actual_end_at
  - [x] status
  - [x] reschedule_initiator
  - [x] tech_issue
  - [x] first_session_for_student
- [x] Add indexes for tutor_id + student_id

- [x] Create SessionTranscript model (TDD: write test → see fail → build model → see pass) (session_id, payload:jsonb)

- [x] Create tables (TDD: write migration tests → see fail → create migrations → see pass):
  - [x] scores (session_id, score_type, value, components:jsonb, computed_at)
  - [x] alerts (tutor_id, alert_type, severity, status, triggered_at, resolved_at, metadata:jsonb)
  - [x] tutor_daily_aggregates (tutor_id, date, sessions_completed, reschedules_tutor_initiated, no_shows, avg_lateness_min, etc.)
  - [x] tutor_churn_scores (tutor_id, tcrs_value, computed_at, components:jsonb) - optional table for caching

- [x] Create materialized views:
  - [x] tutor_stats_7d (rolling 7-day window for THS)
  - [x] tutor_stats_14d (rolling 14-day window for TCRS)
- [x] Add refresh functions for materialized views

---

## EPIC 3 — Seed Data Early
- [x] Create seed tutors (10)
- [x] Create seed students (20)
- [x] Generate ~150 sessions (mixed statuses)
- [x] Set first_session_for_student correctly

- [x] Add ~20 mock transcript payloads (with speaker diarization)
- [x] Create `rails db:reset && rails db:seed` script (db:reset already includes seed)

---

## EPIC 4 — Scoring Services (TDD Approach)
### SQS (Session Quality Score)
- [x] Write SQS service tests (TDD: write test → see fail → build service → see pass)
- [x] Compute lateness penalty: `min(20, 2 * lateness_min)`
- [x] Compute duration shortfall penalty: `min(10, 1 * end_shortfall_min)`
- [x] Compute tech disruption penalty: `10 if tech_issue else 0`
- [x] Calculate final SQS: `clamp(0, 100, base - penalties)`
- [x] Apply label thresholds (risk <60, warn 60-75, ok >75)
- [x] Write score to `scores` table with components breakdown

### FSRS (First Session Risk Score)
- [x] Write FSRS service tests (TDD: write test → see fail → build service → see pass)
- [x] Detect confusion phrases (>=3 instances in student turns) → +20
- [x] Compute tutor vs student word share (tutor >75% of words) → +20
- [x] Detect missing goal-setting question early in session → +25
- [x] Detect missing encouragement phrases → +15
- [x] Detect negative phrasing streak → +10
- [x] Detect missing closing summary or next steps → +20
- [x] Apply tech/lateness disruption penalty → +10 if present
- [x] Calculate final FSRS (sum of risk points)
- [x] Generate structured feedback payload:
  - [x] "What went well" (positive signals)
  - [x] "One improvement idea" (highest-impact issue)
  - [x] Breakdown by component
- [x] Write FSRS to `scores` table (only for first_session_for_student = true)
- [x] Skip FSRS if transcript lacks speaker diarization

### Alert Generation
- [x] Write AlertService tests (TDD: write test → see fail → build service → see pass)
- [x] Create AlertService to evaluate triggers:
  - [x] FSRS ≥ 50 → "Poor first session" alert
  - [x] THS < 55 → "High reliability risk" alert
  - [x] TCRS ≥ 0.6 → "Churn risk" alert
- [x] Write AlertJob tests (TDD: write test → see fail → build job → see pass)
- [x] Create AlertJob to run every 10 min
- [x] Generate alerts in `alerts` table
- [x] Auto-resolve alerts when conditions improve

---

## EPIC 5 — Tutor Dashboard (`/tutor/:id`) (TDD Approach)
- [x] Create React route `/tutor/:id`

### API Endpoints (TDD: write request specs → see fail → build endpoints → see pass)
- [x] Write API endpoint tests (TDD: write test → see fail → build endpoint → see pass) for `GET /api/tutor/:id/fsrs_latest`
- [x] `GET /api/tutor/:id/fsrs_latest` - Most recent FSRS with feedback
- [x] Write API endpoint tests (TDD: write test → see fail → build endpoint → see pass) for `GET /api/tutor/:id/fsrs_history`
- [x] `GET /api/tutor/:id/fsrs_history` - Last 5 first-sessions with FSRS
- [x] Write API endpoint tests (TDD: write test → see fail → build endpoint → see pass) for `GET /api/tutor/:id/performance_summary`
- [x] `GET /api/tutor/:id/performance_summary` - AI-generated summary (template-based for MVP)
- [x] Write API endpoint tests (TDD: write test → see fail → build endpoint → see pass) for `GET /api/tutor/:id/session_list`
- [x] `GET /api/tutor/:id/session_list` - Recent sessions with SQS values

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

## EPIC 6 — Admin Dashboard (`/admin/:id`) (TDD Approach)
- [x] Create React route `/admin/:id`

### API Endpoints (TDD: write request specs → see fail → build endpoints → see pass)
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

## EPIC 7 — Reliability & Churn Jobs (TDD Approach)
### Daily Aggregation Job
- [ ] Write TutorDailyAggregationJob tests (TDD: write test → see fail → build job → see pass)
- [ ] Create TutorDailyAggregationJob
- [ ] Compute tutor_daily_aggregates for completed sessions
- [ ] Calculate: sessions_completed, reschedules_tutor_initiated, no_shows, avg_lateness_min
- [ ] Schedule: every 10 minutes
- [ ] Refresh tutor_stats_7d materialized view after aggregation

### THS (Tutor Health Score) Job
- [ ] Write TutorHealthScoreJob tests (TDD: write test → see fail → build job → see pass)
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
- [ ] Write TutorChurnRiskScoreJob tests (TDD: write test → see fail → build job → see pass)
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
- [ ] Write SessionScoringJob tests (TDD: write test → see fail → build job → see pass)
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

## EPIC 8 — Performance Summary Generation (TDD Approach)
- [ ] Write PerformanceSummaryService tests (TDD: write test → see fail → build service → see pass)
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

---

## EPIC 10 — Email Notifications (Post-MVP)
- [ ] Configure ActionMailer for email delivery
- [ ] Set up SMTP settings (development and production)
- [ ] Create AlertMailer with email templates:
  - [ ] Poor first session alert email
  - [ ] High reliability risk alert email
  - [ ] Churn risk alert email
- [ ] Update AlertService to send emails when alerts are created:
  - [ ] Send email to admin/coach when alert is triggered
  - [ ] Include alert details and tutor information
  - [ ] Add link to admin dashboard for alert management
- [ ] Add email preferences/configuration:
  - [ ] Allow admins to configure email recipients
  - [ ] Support email frequency settings (immediate, daily digest, etc.)
- [ ] Test email delivery in development and staging
- [ ] Document email notification system
