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
- [x] Fetch most recent FSRS via `/api/tutor/:id/fsrs_latest`
- [x] Display "First Session Quality Feedback" card:
  - [x] SQS + FSRS indicators (visually separated)
  - [x] "What went well" section
  - [x] "One improvement idea" section
- [x] FSRS Trend component:
  - [x] Fetch FSRS history via `/api/tutor/:id/fsrs_history`
  - [x] Display sparkline chart (last 5 first-sessions)
  - [x] Show average FSRS score
  - [x] Highlight improvement direction (e.g., +12% vs previous period)
- [x] "View Past First Sessions" link → side panel:
  - [x] List of previous FSRS summary entries
  - [x] Each entry expandable with transcript-based explanation snippets

### Performance Summary Section (second)
- [x] Fetch summary via `/api/tutor/:id/performance_summary`
- [x] Display AI-generated text in UI
- [x] Show SQS trend visualization

### Recent Sessions Table
- [x] Fetch sessions via `/api/tutor/:id/session_list`
- [x] Display table with: Date, Student, SQS, FSRS Tag, Notes

---

## EPIC 6 — Admin Dashboard (`/admin/:id`) (TDD Approach)
- [x] Create React route `/admin/:id`

### API Endpoints (TDD: write request specs → see fail → build endpoints → see pass)
- [x] Write API endpoint tests (TDD: write test → see fail → build endpoint → see pass) for `GET /api/admin/tutors/risk_list`
- [x] `GET /api/admin/tutors/risk_list` - Sorted list with FSRS + THS + TCRS
- [x] `GET /api/admin/tutor/:id/metrics` - Full metrics breakdown
- [x] `GET /api/admin/tutor/:id/fsrs_history` - FSRS history for tutor
- [x] `GET /api/admin/tutor/:id/intervention_log` - Past interventions
- [x] `POST /api/admin/alerts/:id/update_status` - Update alert status

### Risk Overview Table
- [x] Fetch tutors via `/api/admin/tutors/risk_list`
- [x] Sort by risk (Reschedule, No-Show, Churn)
- [x] Display: Tutor Name, Status Badges, FSRS, THS, TCRS, Alert Status

### Tutor Detail Panel
- [x] Header: Tutor Name + Status Badges (Risk / Reliability / Churn)
- [x] SQS Trend: Sparkline of last N sessions
- [x] FSRS Overview: Last first-session score displayed
- [x] THS value with label
- [x] TCRS value with label
- [x] Intervention Log: Past resolved alerts with details

### Alerts Management (Basic Implementation)
- [x] Fetch past interventions for tutor
- [x] Display alerts list with status
- [ ] Status update button (assign coach, mark outreach done, add note) - Can be added post-MVP

---

## EPIC 7 — Reliability & Churn Jobs (TDD Approach)

### ✅ COMPLETED FOR MVP:

### Daily Aggregation Job (POST-MVP - Deferred)
- [ ] Write TutorDailyAggregationJob tests (POST-MVP)
- [ ] Create TutorDailyAggregationJob (POST-MVP)
- [ ] Compute tutor_daily_aggregates for completed sessions (POST-MVP)
- [ ] Calculate: sessions_completed, reschedules_tutor_initiated, no_shows, avg_lateness_min (POST-MVP)
- [ ] Schedule: every 10 minutes (POST-MVP)
- [ ] Refresh tutor_stats_7d materialized view after aggregation (POST-MVP)
- **Note:** Deferred pending materialized views implementation

### THS (Tutor Health Score) Job (POST-MVP - Deferred)
- [ ] Write TutorHealthScoreJob tests (POST-MVP)
- [ ] Create TutorHealthScoreJob (POST-MVP)
- [ ] Compute from tutor_stats_7d (POST-MVP)
- [ ] Calculate THS score (0-100) (POST-MVP)
- [ ] Apply label thresholds (<55 = high risk, 55-75 = monitor, >75 = stable) (POST-MVP)
- [ ] Write to scores table (POST-MVP)
- [ ] Schedule: every 10 minutes (POST-MVP)
- **Note:** Deferred pending tutor_stats_7d materialized view

### TCRS (Tutor Churn Risk Score) Job (POST-MVP - Deferred)
- [ ] Write TutorChurnRiskScoreJob tests (POST-MVP)
- [ ] Create TutorChurnRiskScoreJob (POST-MVP)
- [ ] Compute from tutor_stats_14d (POST-MVP)
- [ ] Calculate TCRS score (0-1 scale) (POST-MVP)
- [ ] Apply thresholds (≥0.6 = Support Check-In, 0.3-0.59 = Monitor, <0.3 = Stable) (POST-MVP)
- [ ] Schedule: every 10 minutes (POST-MVP)
- **Note:** Deferred pending tutor_stats_14d materialized view

### Scoring Job
- [x] Write SessionScoringJob tests (TDD: write test → see fail → build job → see pass)
- [x] Create SessionScoringJob
- [x] Poll for new/updated sessions (DB polling every 5 min)
- [x] Compute SQS for all completed sessions
- [x] Compute FSRS for first_session_for_student = true (if transcript available)
- [x] Write scores to scores table
- [x] Schedule: every 5 minutes

### Alert Job
- [x] Write AlertJob tests (TDD: write test → see fail → build job → see pass)
- [x] Create AlertJob (uses AlertService)
- [x] Evaluate FSRS thresholds (≥50 = poor first session alert)
- [x] Evaluate THS thresholds (<55 = high reliability risk alert)
- [x] Evaluate TCRS thresholds (≥0.6 = churn risk alert)
- [x] Prevent duplicate alerts (keeps existing alerts open)
- [x] Auto-resolve alerts when conditions improve
- [x] Schedule: every 10 minutes

### Job Scheduling Configuration
- [x] Configure sidekiq-scheduler
- [x] Set up recurring jobs:
  - [x] SessionScoringJob: every 5 min
  - [x] AlertJob: every 10 min
  - [ ] TutorDailyAggregationJob: every 10 min (POST-MVP - requires materialized views)
  - [ ] TutorHealthScoreJob: every 10 min (POST-MVP - requires tutor_stats_7d view)
  - [ ] TutorChurnRiskScoreJob: every 10 min (POST-MVP - requires tutor_stats_14d view)

---

## EPIC 8 — Performance Summary Generation (TDD Approach)
- [x] Write PerformanceSummaryService tests (TDD: write test → see fail → build service → see pass)
- [x] Create PerformanceSummaryService
- [x] Template-based approach for MVP:
  - [x] Analyze recent SQS trends
  - [x] Identify patterns (improving, declining, stable)
  - [x] Generate encouraging, supportive text
  - [x] Highlight "What went well" and "One improvement suggestion"
- [x] Integrated with existing API endpoint: `GET /api/tutor/:id/performance_summary`
- [ ] Cache summary for tutor (refresh daily) - POST-MVP optimization

---

## EPIC 9 — Demo Polish
- [x] Create narrative data profiles:
  - [x] Strong tutor (high SQS, low FSRS, stable THS/TCRS) - Sarah Excellence
  - [x] Improving tutor (positive trend) - James Improving
  - [x] Slipping tutor (declining metrics) - Maria Declining
  - [x] Churn-risk tutor (high TCRS, low engagement) - Alex ChurnRisk
- [x] Prepare demo walk-through steps (3 scenarios documented)
- [x] Document demo scenarios (comprehensive DEMO_GUIDE.md created)

---

## EPIC 10 — Email Notifications ✅ COMPLETE
- [x] Configure ActionMailer for email delivery (development: letter_opener, production: SMTP)
- [x] Set up SMTP settings (development and production)
- [x] Create AlertMailer with email templates:
  - [x] Poor first session alert email (HTML + plain text)
  - [x] High reliability risk alert email (HTML + plain text)
  - [x] Churn risk alert email (HTML + plain text)
- [x] Update AlertService to send emails when alerts are created:
  - [x] Send email to admin/coach when alert is triggered
  - [x] Include alert details and tutor information
  - [x] Add link to admin dashboard for alert management
  - [x] Use deliver_later for async delivery via Sidekiq
- [ ] Add email preferences/configuration (FUTURE ENHANCEMENT):
  - Documented in EMAIL_NOTIFICATIONS.md
  - Multiple recipients support
  - Alert type filtering
  - Frequency settings (immediate, daily digest, weekly summary)
  - Unsubscribe functionality
- [x] Test email delivery in development (letter_opener auto-opens in browser)
- [x] Document email notification system (docs/EMAIL_NOTIFICATIONS.md)
