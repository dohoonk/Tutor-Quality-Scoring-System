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

---

## EPIC 11 — Refactor FSRS to FSQS (First Session Quality Score)

**Goal:** Rename FSRS (First Session Risk Score) to FSQS (First Session Quality Score) and invert scoring system from "lower is better" to "higher is better" for consistency with SQS. New scoring: 100 (perfect) - penalties = final score.

### Task 11.1: Update Core Scoring Service ✅
- [x] Rename `FirstSessionRiskScoreService` to `FirstSessionQualityScoreService`
- [x] Update score calculation to start at 100 and subtract penalties
- [x] Update MAX_SCORE constant from 120 to 100
- [x] Update component penalty values to fit 0-100 scale:
  - [x] Missing Goal Setting: 25 → 20
  - [x] Confusion Phrases: 20 → 20
  - [x] Word Share Imbalance: 20 → 20
  - [x] Missing Closing Summary: 20 → 15
  - [x] Missing Encouragement: 15 → 10
  - [x] Tech/Lateness Disruption: 10 → 10
  - [x] Negative Phrasing: 10 → 5
  - [x] **New Total: 100 points**
- [x] Update feedback generation to reflect quality scoring (higher is better)
- [x] Add comments explaining inverted scoring system

### Task 11.2: Update Database & Model References ✅
- [x] Update Score model validation: `%w[sqs fsrs ths tcrs]` → `%w[sqs fsqs ths tcrs]`
- [x] Create database migration to rename score_type from 'fsrs' to 'fsqs'
- [x] Update all existing scores in database
- [x] Update job references (SessionScoringJob, etc.)

### Task 11.3: Update Alert System ✅
- [x] Update AlertService threshold: `>= 50` → `<= 50` (inverted)
- [x] Rename alert mailer views: `poor_first_session_alert` → `low_first_session_quality_alert`
- [x] Update email templates to reflect FSQS naming
- [x] Update email content: "Risk Score" → "Quality Score"
- [x] Update threshold explanations in emails (higher is better)

### Task 11.4: Update API Endpoints ✅
- [x] Rename API routes:
  - [x] `/api/tutor/:id/fsrs_latest` → `/api/tutor/:id/fsqs_latest`
  - [x] `/api/tutor/:id/fsrs_history` → `/api/tutor/:id/fsqs_history`
  - [x] `/api/admin/tutor/:id/fsrs_history` → `/api/admin/tutor/:id/fsqs_history`
- [x] Update controller methods and logic
- [x] Update admin API risk scoring algorithm (invert FSQS comparison)
- [ ] Maintain backward compatibility (optional: support both endpoints temporarily)

### Task 11.5: Update Frontend Components
- [ ] Update TutorDashboard.jsx:
  - [ ] Rename all `fsrs` variables to `fsqs`
  - [ ] Update API endpoint calls
  - [ ] Invert threshold logic: `>= 50` → `<= 50`, `>= 30` → `<= 70`
  - [ ] Update tooltips: "Risk Score" → "Quality Score", explain higher is better
  - [ ] Update trend indicators: ↑ = improvement, ↓ = decline
  - [ ] Update labels: "FSRS" → "FSQS"
- [ ] Update AdminDashboard.jsx:
  - [ ] Rename all `fsrs` variables to `fsqs`
  - [ ] Update getRiskBadge logic (invert thresholds)
  - [ ] Update metric cards: "First Session Risk Score" → "First Session Quality Score"
  - [ ] Invert color coding logic
- [ ] Update session table displays (both dashboards)

### Task 11.6: Update All Tests
- [ ] Update service specs:
  - [ ] Rename `first_session_risk_score_service_spec.rb` → `first_session_quality_score_service_spec.rb`
  - [ ] Update all score expectations (invert values)
  - [ ] Update test descriptions and assertions
- [ ] Update job specs:
  - [ ] `session_scoring_job_spec.rb` - update FSQS expectations
  - [ ] `alert_job_spec.rb` - update threshold tests
- [ ] Update request specs:
  - [ ] `api/tutor_api_spec.rb` - rename endpoints, update expectations
  - [ ] `api/admin_api_spec.rb` - update risk scoring tests
- [ ] Update mailer specs:
  - [ ] `alert_mailer_spec.rb` - update FSQS expectations
- [ ] Update alert service specs:
  - [ ] Invert threshold expectations

### Task 11.7: Update Documentation
- [ ] Update `docs/prd.md`:
  - [ ] Replace all FSRS references with FSQS
  - [ ] Update scoring explanation (100 = perfect, 0 = worst)
  - [ ] Update threshold descriptions
- [ ] Update `docs/architecture.md`:
  - [ ] Rename service references
  - [ ] Update API endpoint documentation
  - [ ] Update scoring system explanation
- [ ] Update `docs/PROJECT_SUMMARY.md`:
  - [ ] Update FSQS description
  - [ ] Update metrics explanation
- [ ] Update `docs/tasks.md`:
  - [ ] Update EPIC 4 task descriptions (historical record)
- [ ] Update `docs/DEMO_GUIDE.md`:
  - [ ] Update demo profile scores to reflect 0-100 scale
  - [ ] Update script explanations
- [ ] Update `docs/MANUAL_TESTING.md`:
  - [ ] Update test procedures for FSQS
  - [ ] Update expected values
- [ ] Update `docs/EMAIL_NOTIFICATIONS.md`:
  - [ ] Update threshold explanations
  - [ ] Update alert type descriptions
- [ ] Update README.md if it contains FSRS references

### Task 11.8: Clean Up Legacy Code
- [ ] Remove or update legacy `compute_fsrs` method in SessionScoringJob (if exists)
- [ ] Update any remaining comments referencing "risk" to "quality"
- [ ] Remove old service file after renaming

### Task 11.9: Testing & Verification
- [ ] Run full test suite and ensure all tests pass
- [ ] Test score calculation manually with sample data
- [ ] Verify alert thresholds work correctly
- [ ] Test API endpoints return correct data
- [ ] Test frontend displays scores correctly
- [ ] Verify email notifications show correct information
- [ ] Test both dashboards (tutor and admin)

### Task 11.10: Database Migration & Deployment
- [ ] Create data migration script to update existing scores
- [ ] Test migration on development data
- [ ] Document rollback procedure
- [ ] Update deployment notes
- [ ] Plan for zero-downtime migration if needed

---
