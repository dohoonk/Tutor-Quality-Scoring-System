# Tutor Quality Scoring System

A comprehensive system that transforms 3,000+ daily tutoring sessions into actionable insights, proactively identifying at-risk tutors before problems escalate. The system automatically computes quality scores, tracks reliability metrics, predicts churn risk, and provides both tutors and admins with actionable dashboards.

## Table of Contents

- [Overview](#overview)
- [Tech Stack](#tech-stack)
- [System Architecture](#system-architecture)
- [Assumptions](#assumptions)
- [Data Structure](#data-structure)
- [Caching Strategy](#caching-strategy)
- [How It Works](#how-it-works)
- [Setup Instructions](#setup-instructions)
- [Background Jobs](#background-jobs)
- [Scoring Details](#scoring-details)
- [API Endpoints](#api-endpoints)
- [Development](#development)
- [Testing](#testing)
- [Deployment](#deployment)

## Overview

This system provides:

- **Automated Scoring**: Real-time computation of session quality, first-session quality, tutor health, and churn risk scores
- **Intelligent Alerting**: Automatic alert generation when tutors exceed risk thresholds
- **Tutor Dashboard**: Self-improvement focused dashboard for tutors to track their performance
- **Admin Dashboard**: Risk management dashboard for operational triage and intervention tracking
- **AI-Powered Feedback**: LLM-based analysis of session transcripts for personalized coaching suggestions

All insights are available within **60 minutes** of session completion.

## Tech Stack

- **Backend**: Ruby on Rails 8.0
- **Frontend**: React 19 (SPA via Vite)
- **Database**: PostgreSQL
- **Background Jobs**: Sidekiq (Redis-backed) with sidekiq-scheduler
- **Caching**: Rails.cache (MemoryStore in dev, Redis in production)
- **Asset Pipeline**: Vite
- **Styling**: Tailwind CSS
- **AI Integration**: OpenAI API (ruby-openai gem)
- **Email**: Action Mailer (SendGrid/Mailgun in production, letter_opener in development)

## System Architecture

```
Sessions (raw events & metadata)
        ↓
Daily Aggregation (tutor_daily_aggregates)
        ↓
┌─────────────────────────┬─────────────────────────┐
│ 7-Day Rolling Window     │ 14-Day Rolling Window    │
│ (Reliability / No-Show)  │ (Engagement / Churn)     │
│  reschedules_7d          │  sessions_14d            │
│  no_shows_7d             │  availability_14d        │
│  avg_lateness_7d         │  repeat_student_rate_14d │
└─────────────────────────┴─────────────────────────┘
        ↓                                 ↓
Tutor Reliability Score (THS)      Tutor Churn Risk Score (TCRS)
        ↓                                 ↓
      Admin Dashboard (Risk Triage)  &  Tutor Dashboard (Self-Improvement)
```

### Components

1. **Rails API**: RESTful endpoints for dashboards and data access
2. **Sidekiq Jobs**: Scheduled background processing for scoring and aggregation
3. **Scoring Services**: Business logic for computing scores
4. **React Dashboards**: Frontend applications for tutors and admins
5. **Alert System**: Automated risk detection and notification

## Assumptions

The system is built on the following assumptions:

### Data Availability

- **Transcript Availability**: Session transcripts are available in a structured format with speaker diarization (tutor vs student). If diarization is absent for a session, **FSQS is not computed**.
- **Timing Metadata**: `scheduled_start_at`, `actual_start_at`, `scheduled_end_at`, and `actual_end_at` timestamps are reliably captured to derive lateness and session duration.
- **Tech Issue Flag**: A binary `tech_issue` indicator is available per session (source-agnostic, no blame attribution).
- **Session Identification**: We can reliably detect when a session is a **first session between a tutor and a student** (via absence of prior sessions in DB).

### System Behavior

- **Tutor Churn Definition**: Churn is defined as **tutor deactivation** (not inactivity window) for the MVP.
- **Event Delivery**: MVP uses **DB polling** for new/updated sessions; event bus integration is **post-MVP**.
- **Intervention Execution**: Coach/Admin actions are **logged internally only** (no automated scheduling or messaging changes in MVP).
- **Message Latency Data**: Not required for MVP; may be included post-MVP.

### Scoring Philosophy

- **No Fault Attribution**: We score what the student experienced, not who is at fault.
  - Lateness, ending early, and tech issues affect **SQS (Session Quality Score)** and **FSQS (First Session Quality Score)** because they change the student experience.
  - These signals **do not reduce THS (Tutor Health Score)** unless the pattern is repeated and clearly behavioral (e.g., repeated tutor-initiated lateness or no-shows).
- **Fairness**: The system is designed to be fair to tutors while aligned to student retention goals.

## Data Structure

### Database Schema

#### Core Tables

**`sessions`**
- `id`: Primary key
- `tutor_id`: Foreign key to tutors
- `student_id`: Foreign key to students
- `scheduled_start_at`: When the session was scheduled to start
- `actual_start_at`: When the session actually started
- `scheduled_end_at`: When the session was scheduled to end
- `actual_end_at`: When the session actually ended
- `status`: `'completed'`, `'cancelled'`, `'no_show'`, `'rescheduled'`
- `reschedule_initiator`: `'tutor'`, `'student'`, or `null`
- `tech_issue`: Boolean flag for technical issues
- `first_session_for_student`: Boolean indicating first session between tutor and student
- Indexes: `tutor_id`, `student_id`, `(tutor_id, student_id)`

**`session_transcripts`**
- `id`: Primary key
- `session_id`: Foreign key to sessions
- `payload`: JSONB containing transcript data with speaker diarization

**`scores`**
- `id`: Primary key
- `session_id`: Foreign key to sessions (nullable for aggregate scores)
- `tutor_id`: Foreign key to tutors (required)
- `score_type`: `'sqs'`, `'fsqs'`, `'ths'`, `'tcrs'`
- `value`: Decimal score value
- `components`: JSONB breakdown of score components
- `computed_at`: Timestamp when score was computed
- Indexes: `(tutor_id, score_type)`, `session_id`

**`tutor_daily_aggregates`**
- `id`: Primary key
- `tutor_id`: Foreign key to tutors
- `date`: Date of aggregation
- `sessions_completed`: Count of completed sessions
- `reschedules_tutor_initiated`: Count of tutor-initiated reschedules
- `no_shows`: Count of no-show sessions
- `avg_lateness_min`: Average lateness in minutes
- Unique index: `(tutor_id, date)`

**`alerts`**
- `id`: Primary key
- `tutor_id`: Foreign key to tutors
- `alert_type`: `'low_first_session_quality'`, `'high_reliability_risk'`, `'churn_risk'`
- `severity`: `'high'`, `'medium'`, `'low'`
- `status`: `'open'`, `'resolved'`, `'acknowledged'`
- `triggered_at`: When the alert was triggered
- `resolved_at`: When the alert was resolved (nullable)
- `metadata`: JSONB with trigger details and intervention notes
- Index: `tutor_id`

**`tutors`**
- `id`: Primary key
- `name`: Tutor name
- `email`: Tutor email

**`students`**
- `id`: Primary key
- `name`: Student name
- `email`: Student email

#### Materialized Views

**`tutor_stats_7d`** (Rolling 7-day window for THS)
- Aggregates: Reschedules (tutor-initiated), no-shows, lateness patterns
- Refreshed after daily aggregation job

**`tutor_stats_14d`** (Rolling 14-day window for TCRS)
- Aggregates: Sessions completed, availability, repeat student rate
- Refreshed after daily aggregation job

### Data Flow

1. **Session Creation**: Sessions are created with metadata
2. **Scoring**: `SessionScoringJob` computes SQS and FSQS for completed sessions
3. **Aggregation**: `TutorDailyAggregationJob` aggregates daily metrics
4. **Health Scoring**: `TutorHealthScoreJob` computes THS from 7-day metrics
5. **Churn Scoring**: `TutorChurnRiskScoreJob` computes TCRS from 14-day metrics
6. **Alerting**: `AlertJob` evaluates triggers and generates alerts
7. **Dashboards**: React frontend queries APIs for real-time display

## Caching Strategy

### Performance Summary Caching

**Technology**: Rails.cache (MemoryStore in development, Redis in production)

**Cache Key Pattern**: `performance_summary:tutor:{tutor_id}`

**TTL**: 1 hour

**Data Cached**: Full performance summary including trend analysis, average scores, and feedback

### Cache Invalidation

The cache is automatically invalidated (busted) when:
- New SQS (Session Quality Score) is computed for a tutor
- Triggered by `SessionScoringJob` after creating scores
- Ensures dashboard always reflects latest session data

### Benefits

1. **Reduced Database Load**: Avoids repeated aggregation queries for the same tutor
2. **Faster Dashboard Response**: Cached summaries return in < 1ms vs ~50ms for computation
3. **Scalability**: Handles 3,000+ daily sessions with minimal latency
4. **Stale Data Prevention**: 1-hour TTL ensures data freshness even if cache isn't busted

### Configuration

**Development**: Uses `:memory_store` (in-memory caching)

**Production**: Requires Redis configuration:
```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] }
```

## How It Works

### Scoring Pipeline

1. **Session Scoring** (every 5 minutes)
   - Computes SQS for all completed sessions
   - Computes FSQS for first sessions with transcripts
   - Saves scores to `scores` table

2. **Daily Aggregation** (every 10 minutes)
   - Aggregates daily metrics per tutor
   - Updates `tutor_daily_aggregates` table
   - Refreshes materialized views (`tutor_stats_7d`, `tutor_stats_14d`)

3. **Health Scoring** (every 10 minutes)
   - Computes THS from 7-day rolling window
   - Saves to `scores` table

4. **Churn Risk Scoring** (every 10 minutes)
   - Computes TCRS from 14-day rolling window
   - Saves to `scores` table

5. **Alert Generation** (every 10 minutes)
   - Evaluates score thresholds
   - Creates/updates alerts in `alerts` table
   - Sends email notifications
   - Auto-resolves when conditions improve

### Service Architecture

- **SessionQualityScoreService**: Computes SQS per session
- **FirstSessionQualityScoreService**: Computes FSQS for first sessions
- **PerformanceSummaryService**: Generates tutor performance summaries (cached)
- **SqsActionableFeedbackService**: Generates actionable items from last 10 SQS scores
- **AIActionableFeedbackService**: Generates AI-powered detailed feedback using last 5 session transcripts
- **AlertService**: Evaluates triggers and generates alerts

### Frontend Architecture

- **Tutor Dashboard** (`/tutor/:id`): Self-improvement focused React SPA
- **Admin Dashboard** (`/admin/:id`): Risk management React SPA
- Both use Vite for hot-reload development and optimized production builds

## Setup Instructions

### Prerequisites

- Ruby 3.3+ (check with `ruby -v`)
- Node.js 18+ and npm (check with `node -v` and `npm -v`)
- PostgreSQL 14+ (check with `psql --version`)
- Redis 6+ (check with `redis-cli --version`)

### Step 1: Clone and Install

```bash
# Clone repository
git clone <repository-url>
cd tutor-insights

# Install Ruby dependencies
bundle install

# Install JavaScript dependencies
npm install
```

### Step 2: Database Setup

```bash
# Create database
rails db:create

# Run migrations
rails db:migrate

# Seed database with initial data
rails db:seed

# Load demo profiles (optional, for testing)
rails runner db/seeds/demo_profiles.rb
```

### Step 3: Environment Configuration

Create a `.env` file in the project root:

```bash
# Database
DATABASE_URL=postgresql://localhost/tutor_insights_development

# Redis (for Sidekiq and caching)
REDIS_URL=redis://localhost:6379/0

# Email Configuration (development)
ADMIN_EMAIL=admin@example.com

# For production email (SendGrid example)
# SMTP_ADDRESS=smtp.sendgrid.net
# SMTP_PORT=587
# SMTP_USER_NAME=apikey
# SMTP_PASSWORD=your_sendgrid_api_key
# SMTP_DOMAIN=yourcompany.com
# MAILER_HOST=your-production-domain.com

# OpenAI API (for AI-powered feedback)
# OPENAI_API_KEY=your_openai_api_key_here
```

### Step 4: Start Development Servers

**Option A: Use bin/dev (Recommended)**

```bash
bin/dev
```

This starts:
- Rails server (port 3000)
- Tailwind CSS watcher
- Vite dev server (port 3036)
- Sidekiq (background jobs)

**Option B: Start Manually**

In separate terminal windows:

```bash
# Terminal 1: Rails server
bin/rails server

# Terminal 2: Tailwind CSS
bin/rails tailwindcss:watch

# Terminal 3: Vite dev server
bin/vite dev

# Terminal 4: Sidekiq
bundle exec sidekiq
```

### Step 5: Generate Initial Scores

The dashboards need scores to display. Run scoring jobs:

```bash
rails console
```

Then in the console:

```ruby
# Run scoring job
SessionScoringJob.new.perform

# Run aggregation job
TutorDailyAggregationJob.new.perform

# Run health score job
TutorHealthScoreJob.new.perform

# Run churn risk score job
TutorChurnRiskScoreJob.new.perform

# Run alert job
AlertJob.new.perform
```

Or run all jobs via Sidekiq scheduler (automatic every 5-10 minutes).

### Step 6: Access Dashboards

**Tutor Dashboards:**
- `http://localhost:3000/tutor/11` (Sarah Excellence)
- `http://localhost:3000/tutor/12` (James Improving)
- `http://localhost:3000/tutor/13` (Maria Declining)
- `http://localhost:3000/tutor/14` (Alex ChurnRisk)

**Admin Dashboard:**
- `http://localhost:3000/admin/1`

**Sidekiq Dashboard:**
- `http://localhost:3000/sidekiq`

## Background Jobs

### Scheduled Jobs

| Job | Frequency | Purpose | Dependencies |
|-----|-----------|---------|--------------|
| `SessionScoringJob` | Every 5 min | Compute SQS + FSQS on recent sessions | None |
| `TutorDailyAggregationJob` | Every 10 min | Update `tutor_daily_aggregates` | None |
| `TutorHealthScoreJob` | Every 10 min | Compute THS from `tutor_stats_7d` | After aggregation |
| `TutorChurnRiskScoreJob` | Every 10 min | Compute TCRS from `tutor_stats_14d` | After aggregation |
| `AlertJob` | Every 10 min | Generate or close alerts based on score thresholds | After scoring jobs |

### Job Configuration

Jobs are configured in `config/sidekiq_schedule.yml` and `config/sidekiq_scheduler.rb`.

### Running Jobs Manually

```ruby
# In Rails console
SessionScoringJob.new.perform
TutorDailyAggregationJob.new.perform
TutorHealthScoreJob.new.perform
TutorChurnRiskScoreJob.new.perform
AlertJob.new.perform
```

## Scoring Details

### SQS (Session Quality Score)

**Formula**: `base(80) - lateness_penalty - shortfall_penalty - tech_penalty`

**Applied to**: All completed sessions

**Labels**:
- `risk` (< 60)
- `warn` (60-75)
- `ok` (> 75)

**Components**:
- Lateness penalty (minutes late)
- Shortfall penalty (ending early)
- Tech issue penalty (10 points)

### FSQS (First Session Quality Score)

**Formula**: Sum of risk points (max 100+)

**Applied to**: Only `first_session_for_student = true`

**Requires**: Speaker diarization in transcript

**Risk Components**:
- No goal-setting question early: +25
- Tutor speaks >75% of words: +20
- No encouragement phrases: +15
- Student confusion ≥3 instances: +20
- No closing summary: +20
- Negative phrasing streak: +10
- Tech/lateness disruption: +10

**Threshold**: FSQS ≥ 50 triggers alert

### THS (Tutor Health Score)

**Formula**: 0-100 scale based on 7-day reliability metrics

**Source**: `tutor_stats_7d` materialized view

**Components**:
- Tutor-initiated reschedule rate
- No-show count
- Behavioral lateness trend (repeated patterns only)
- Quality recovery signals

**Labels**:
- `high risk` (< 55)
- `monitor` (55-75)
- `stable` (> 75)

### TCRS (Tutor Churn Risk Score)

**Formula**: 0-1 scale based on 14-day engagement metrics

**Source**: `tutor_stats_14d` materialized view

**Components**:
- Availability drop vs previous period: +0.4
- Completed sessions drop: +0.3
- Tutor-initiated reschedules rise: +0.15
- Any no-shows: +0.20
- Repeat student rate low: +0.20

**Labels**:
- `Support Check-In` (≥ 0.6)
- `Monitor` (0.3-0.59)
- `Stable` (< 0.3)

## API Endpoints

### Tutor Dashboard (`/tutor/:id`)

- `GET /api/tutor/:id/fsqs_latest` - Most recent FSQS with feedback payload
- `GET /api/tutor/:id/fsqs_history` - Last 5 first-sessions with FSQS scores
- `GET /api/tutor/:id/performance_summary` - AI-generated performance summary (cached)
- `GET /api/tutor/:id/session_list` - Recent sessions with SQS values
- `GET /api/tutor/:id/sqs_actionable_feedback` - Actionable items based on last 10 SQS scores
- `POST /api/tutor/:id/ai_feedback` - Get AI-powered detailed feedback for specific actionable item

### Admin Dashboard (`/admin/:id`)

- `GET /api/admin/tutors/risk_list` - Sorted list of tutors with risk metrics
- `GET /api/admin/tutor/:id/metrics` - Full metrics breakdown for tutor (includes 30-day session metrics)
- `GET /api/admin/tutor/:id/fsqs_history` - FSQS history for tutor
- `GET /api/admin/tutor/:id/intervention_log` - Past interventions and notes
- `POST /api/admin/alerts/:id/update_status` - Update alert status and log interventions

## Development

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/services/session_quality_score_service_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec
```

### Code Quality

```bash
# Run Rubocop
bundle exec rubocop

# Run Brakeman (security)
bundle exec brakeman
```

### Database Console

```bash
rails dbconsole
```

### Rails Console

```bash
rails console
```

## Testing

### Manual Testing

See `docs/MANUAL_TESTING.md` and `docs/ADMIN_DASHBOARD_TESTING.md` for detailed testing guides.

### Test Data

Demo profiles are available via:
```bash
rails runner db/seeds/demo_profiles.rb
```

This creates:
- 10 tutors with varying performance profiles
- 20 students
- ~150 sessions (mixed statuses)
- ~20 session transcripts (for first sessions)

### Generating Test Scores

```bash
rails console
```

```ruby
# Run all scoring jobs
SessionScoringJob.new.perform
TutorDailyAggregationJob.new.perform
TutorHealthScoreJob.new.perform
TutorChurnRiskScoreJob.new.perform
AlertJob.new.perform
```

## Deployment

### Production Environment Variables

```bash
# Required
DATABASE_URL=postgresql://...
REDIS_URL=redis://...

# Email Configuration
ADMIN_EMAIL=admin@yourcompany.com
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER_NAME=apikey
SMTP_PASSWORD=your_sendgrid_api_key
SMTP_DOMAIN=yourcompany.com
MAILER_HOST=your-production-domain.com

# OpenAI API (optional)
OPENAI_API_KEY=your_openai_api_key

# Optional
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2
```

### Deployment Steps

1. **Database Setup**:
   ```bash
   rails db:migrate RAILS_ENV=production
   rails db:seed RAILS_ENV=production
   ```

2. **Asset Compilation**:
   ```bash
   rails assets:precompile RAILS_ENV=production
   npm run build
   ```

3. **Start Services**:
   ```bash
   # Web server (Puma)
   bundle exec puma -C config/puma.rb
   
   # Background jobs (Sidekiq)
   bundle exec sidekiq
   ```

4. **Verify**:
   - Check `/up` endpoint for health
   - Verify Sidekiq dashboard at `/sidekiq`
   - Test alert email delivery

### Docker Deployment

A `Dockerfile` is included for containerized deployment. See `config/deploy.yml` for Kamal deployment configuration.

## Additional Resources

- `docs/architecture.md` - Detailed system architecture
- `docs/prd.md` - Product requirements document
- `docs/CACHING_STRATEGY.md` - Detailed caching documentation
- `docs/PROJECT_SUMMARY.md` - Project overview and status
- `docs/DEMO_GUIDE.md` - Demo scenarios and walkthrough
- `docs/MANUAL_TESTING.md` - Tutor Dashboard testing guide
- `docs/ADMIN_DASHBOARD_TESTING.md` - Admin Dashboard testing guide
- `docs/EMAIL_NOTIFICATIONS.md` - Email system documentation

## License

[Add your license here]

## Support

[Add support contact information here]
