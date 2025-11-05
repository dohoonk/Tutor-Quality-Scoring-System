# System Architecture

This document describes the MVP architecture for the Tutor Quality, Reliability & Churn Prevention System.

## Tech Stack
- **Backend:** Ruby on Rails
- **Frontend:** React (SPA or Rails + React hybrid) via Vite
- **Database:** PostgreSQL
- **Background Jobs:** Sidekiq (Redis-backed) with sidekiq-scheduler
- **Data Processing:** Rails services + scheduled jobs
- **Environment:** dotenv-rails for configuration

## High-Level Overview
The system processes session data, computes scoring metrics, stores rolling aggregates, and exposes dashboards for tutors and admins. All insights are available within 60 minutes of session completion.

## Components
- **Rails API**
  - CRUD for sessions, transcripts, tutor summaries
  - Endpoints for dashboards (see Request/Response Paths below)
- **Sidekiq Jobs**
  - SessionScoringJob: Compute SQS + FSQS on recent sessions (every 5 min)
  - TutorDailyAggregationJob: Aggregate daily metrics (every 10 min)
  - TutorHealthScoreJob: Compute THS from 7d rolling window (every 10 min)
  - TutorChurnRiskScoreJob: Compute TCRS from 14d rolling window (every 10 min)
  - AlertJob: Generate or close alerts based on score thresholds (every 10 min)
- **PostgreSQL Storage**
  - `sessions` - Session events and metadata
  - `session_transcripts` - Transcript payloads with speaker diarization
  - `tutor_daily_aggregates` - Daily aggregated metrics per tutor
  - `tutor_stats_7d` (materialized view) - Rolling 7-day window for THS
  - `tutor_stats_14d` (materialized view) - Rolling 14-day window for TCRS
  - `scores` - All computed scores (SQS, FSQS, THS, TCRS) with components
  - `alerts` - Risk alerts and intervention tracking
  - `tutor_churn_scores` (optional) - Cached TCRS values
- **Scoring Services**
  - SessionQualityScoreService: Computes SQS per session
  - FirstSessionQualityScoreService: Computes FSQS for first sessions
  - TutorHealthScoreService: Computes THS from 7d metrics
  - TutorChurnRiskScoreService: Computes TCRS from 14d metrics
  - AlertService: Evaluates triggers and generates alerts
  - PerformanceSummaryService: Generates tutor performance summaries
- **React Frontend**
  - `/tutor/:id` dashboard - Self-improvement focused
  - `/admin/:id` risk management dashboard - Operational triage

## Data Flow Diagram
```mermaid
flowchart LR

%% Data Sources
A[Sessions Table] -->|raw session events| B[SessionScoringJob]
C[Session Transcripts] --> B

%% Scoring
B --> D[(Scores Table)]
B --> E[AlertService]
E --> F[(Alerts Table)]

%% Aggregates
A --> G[TutorDailyAggregationJob]
G --> H[(tutor_daily_aggregates)]
H --> I[(tutor_stats_7d MV)]
H --> J[(tutor_stats_14d MV)]

%% Health & Churn Scoring
I --> K[TutorHealthScoreJob]
J --> L[TutorChurnRiskScoreJob]
K --> D
L --> D
L --> E

%% Dashboards
D --> M[Tutor Dashboard (React)]
E --> M
F --> N[Admin Dashboard (React)]
I --> N
J --> N
D --> N
```

## Request/Response Paths

### Tutor Dashboard (`/tutor/:id`)
- `GET /api/tutor/:id/fsqs_latest` - Most recent FSQS with feedback payload
- `GET /api/tutor/:id/fsqs_history` - Last 5 first-sessions with FSQS scores
- `GET /api/tutor/:id/performance_summary` - AI-generated performance summary
- `GET /api/tutor/:id/session_list` - Recent sessions with SQS values

### Admin Dashboard (`/admin/:id`)
- `GET /api/admin/tutors/risk_list` - Sorted list of tutors with risk metrics
- `GET /api/admin/tutor/:id/metrics` - Full metrics breakdown for tutor
- `GET /api/admin/tutor/:id/fsqs_history` - FSQS history for tutor
- `GET /api/admin/tutor/:id/intervention_log` - Past interventions and notes
- `POST /api/admin/alerts/:id/update_status` - Update alert status and log interventions

## Background Job Schedule

| Job | Frequency | Purpose | Dependencies |
|-----|-----------|---------|--------------|
| SessionScoringJob | every 5 min | Compute SQS + FSQS on recent sessions | None |
| TutorDailyAggregationJob | every 10 min | Update `tutor_daily_aggregates` | None |
| TutorHealthScoreJob | every 10 min | Compute THS from `tutor_stats_7d` | After aggregation |
| TutorChurnRiskScoreJob | every 10 min | Compute TCRS from `tutor_stats_14d` | After aggregation |
| AlertJob | every 10 min | Generate or close alerts based on score thresholds | After scoring jobs |

## Data Model Details

### Sessions
- Timestamps: `scheduled_start_at`, `actual_start_at`, `scheduled_end_at`, `actual_end_at`
- Status: completed, cancelled, no_show, rescheduled
- Metadata: `reschedule_initiator`, `tech_issue`, `first_session_for_student`
- Indexes: `tutor_id`, `student_id`, `(tutor_id, student_id)`

### Scores Table
- `session_id` (nullable for aggregate scores)
- `tutor_id` (required)
- `score_type`: 'sqs', 'fsrs', 'ths', 'tcrs'
- `value`: numeric score
- `components`: jsonb breakdown of score components
- `computed_at`: timestamp
- Indexes: `(tutor_id, score_type)`, `session_id`

### Alerts Table
- `tutor_id`: foreign key
- `alert_type`: 'low_first_session_quality', 'high_reliability_risk', 'churn_risk'
- `severity`: 'high', 'medium', 'low'
- `status`: 'open', 'resolved', 'acknowledged'
- `triggered_at`, `resolved_at`: timestamps
- `metadata`: jsonb with trigger details and intervention notes

### Materialized Views
- `tutor_stats_7d`: Rolling 7-day aggregates for THS calculation
  - Reschedules (tutor-initiated), no-shows, lateness patterns
- `tutor_stats_14d`: Rolling 14-day aggregates for TCRS calculation
  - Sessions completed, availability, repeat student rate
- Refresh: Triggered after daily aggregation job

## Scoring Details

### SQS (Session Quality Score)
- Formula: `base(80) - lateness_penalty - shortfall_penalty - tech_penalty`
- Applied to: All completed sessions
- Labels: risk (<60), warn (60-75), ok (>75)

### FSQS (First Session Quality Score)
- Formula: Sum of risk points (max 100+)
- Components:
  - No goal-setting question early: +25
  - Tutor speaks >75% of words: +20
  - No encouragement phrases: +15
  - Student confusion ≥3 instances: +20
  - No closing summary: +20
  - Negative phrasing streak: +10
  - Tech/lateness disruption: +10
- Applied to: Only `first_session_for_student = true`
- Requires: Speaker diarization in transcript
- Threshold: FSQS ≥ 50 triggers alert

### THS (Tutor Health Score)
- Formula: 0-100 scale based on 7-day reliability metrics
- Components:
  - Tutor-initiated reschedule rate
  - No-show count
  - Behavioral lateness trend (repeated patterns only)
  - Quality recovery signals
- Labels: high risk (<55), monitor (55-75), stable (>75)
- Source: `tutor_stats_7d` materialized view

### TCRS (Tutor Churn Risk Score)
- Formula: 0-1 scale based on 14-day engagement metrics
- Components:
  - Availability drop vs previous period: +0.4
  - Completed sessions drop: +0.3
  - Tutor-initiated reschedules rise: +0.15
  - Any no-shows: +0.20
  - Repeat student rate low: +0.20
- Labels: Support Check-In (≥0.6), Monitor (0.3-0.59), Stable (<0.3)
- Source: `tutor_stats_14d` materialized view

## Alert Triggers

| Trigger | Condition | Alert Type | Severity |
|---------|-----------|------------|----------|
| Low first session quality | FSQS ≥ 50 | low_first_session_quality | medium |
| High reliability risk | THS < 55 | high_reliability_risk | high |
| Churn risk | TCRS ≥ 0.6 | churn_risk | high |

Alerts auto-resolve when conditions improve.

## Performance Summary Generation

- Service: `PerformanceSummaryService`
- Approach: Template-based for MVP (rule-based text generation)
- Inputs: Recent SQS trends, FSQS history, session patterns
- Outputs: Encouraging, supportive text with:
  - "What went well" highlights
  - "One improvement suggestion"
- Caching: Daily refresh per tutor

## Notes for Implementation
- Start with DB polling; event bus may be added post-MVP.
- FSQS requires diarized transcript; skip FSQS if absent.
- Tech issues + lateness affect session experience scores (SQS/FSQS), **not** tutor reliability scores (THS).
- Churn detection uses explicit deactivation as ground truth for now.
- Use sidekiq-scheduler for recurring job definitions.
- Materialized views refresh after aggregation jobs complete.
- All scoring services should be idempotent (safe to re-run).

## Next Steps
- Implement migrations with materialized views
- Implement scoring services (SQS, FSQS, THS, TCRS)
- Build alert generation system
- Configure job scheduling
- Build React Tutor dashboard
- Build React Admin dashboard
