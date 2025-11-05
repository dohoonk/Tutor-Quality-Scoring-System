# Tutor Quality, Reliability & Churn Prevention System — PRD v2

## 1) Objective
Build a system that:
- Scores **session quality** (especially first session experiences)
- Monitors **tutor reliability** (reschedules, lateness, no-shows)
- Predicts **tutor churn likelihood** based on engagement behavior
- Surfaces **actionable, supportive interventions** for coaches and tutors

The system should evaluate ~3,000 sessions/day and provide insights **within 60 minutes** of session completion.

---

## 2) Users & Dashboards

### **Tutor Dashboard

### FSQS Feedback Section
- Place **above** performance summary, as a prominent card.
- **Show most recent FSQS result** with:
  - Label: `First Session Quality Feedback`
  - SQS + FSQS indicators visually separated
  - Key highlights (what went well, what to try next)
- **Aggregate FSQS Trend** (last 5 first-sessions with different students):
  - Small sparkline + average FSQS score
  - Highlight improvement direction (e.g., +12% vs previous period)
- **"View Past First Sessions"** link → opens side panel:
  - List of previous FSQS summary entries
  - Each entry expandable into transcript-based explanation snippets

### Performance Summary (AI-Generated) Section (now second)
- Remains below FSQS block as previously defined (`/tutor/:id`)
- Audience: Tutors
- Tone: Encouraging, supportive, growth-oriented
- Purpose: Help tutors self-improve, gain confidence, track progress.

Key UI:
- Performance summary trends (Session Quality Score)
- Highlights: "What went well" & "One improvement suggestion"
- Recent session breakdowns with FSQS feedback
- API: `GET /api/tutor/:id/performance_summary` (template-based for MVP)

### **Admin / Coach Dashboard** (`/admin/:id`)
Audience: Operations Leads, Coaching Team
Tone: Operational clarity, evidence-driven triage
Purpose: Identify tutors needing support, assign interventions, monitor reliability.

Key UI:
- Priority list sorted by risk (Reschedule, No-Show, Churn)
- Tutor detail panels (trend graphs, incident history, FSQS flags)
- Action workflows: check-in, training resources, schedule resets

---

## 3) Key Metrics
- **SQS (Session Quality Score)** — per session
- **FSQS (First-Session Risk Score)** — transcript-based
- **THS (Tutor Health Score)** — reliability + behavior score (7 days)
- **TCRS (Tutor Churn Risk Score)** — disengagement + stability score (14 days)

---

## 4) Data Model

### `sessions`
Stores final session outcome & transcript reference.
- Fields: scheduled_start_at, actual_start_at, scheduled_end_at, actual_end_at, status, reschedule_initiator, tech_issue, first_session_for_student
- Indexes: tutor_id, student_id, (tutor_id, student_id)

### `session_transcripts`
Stores transcript payloads with speaker diarization (jsonb format).
- Required for FSQS computation; FSQS skipped if diarization missing

### `tutor_daily_aggregates`
Aggregates completed sessions, reschedules, no-shows, lateness per day.
- Used as source for materialized views

### Materialized Views:
- `tutor_stats_7d` → reliability trends (rolling 7-day window for THS)
- `tutor_stats_14d` → churn trends (rolling 14-day window for TCRS)
- Refreshed after daily aggregation job runs

### `scores`
Stores all computed scores with breakdown components.
- Fields: session_id (nullable), tutor_id, score_type (sqs/fsrs/ths/tcrs), value, components (jsonb), computed_at
- Indexes: (tutor_id, score_type), session_id

### `alerts`
Tracks open risk cases and interventions.
- Fields: tutor_id, alert_type, severity, status, triggered_at, resolved_at, metadata (jsonb)
- Types: low_first_session_quality, high_reliability_risk, churn_risk
- **Alert Behavior:**
  - Alerts are evaluated every 10 minutes via AlertJob
  - **No duplicate alerts:** If an alert already exists for a condition and the condition persists, the existing alert remains open (no new alert is created)
  - **Auto-resolve:** Alerts are automatically resolved when conditions improve (e.g., FSQS drops below 50, THS rises above 55, TCRS drops below 0.6)
  - Only one open alert per alert_type per tutor at any given time

---

## 5) Session Quality Scoring (SQS)
```
base = 80
lateness_penalty = min(20, 2 * lateness_min)
shortfall_penalty = min(10, 1 * end_shortfall_min)
tech_penalty = 10 if tech_issue else 0

SQS = clamp(0, 100, base - lateness_penalty - shortfall_penalty - tech_penalty)
```
Label thresholds:
- `<60` = risk
- `60–75` = warning
- `>75` = good

Applied to: All completed sessions

---

## 6) First-Session Experience Scoring (FSQS)
Using transcript + metadata:
```
+25 if no goal-setting question early
+20 if tutor speaks >75% of words
+15 if no encouragement phrases found
+20 if student confusion ≥ 3 instances
+20 if no closing summary or next steps
+10 if negative phrasing streak detected
+10 if tech/lateness disruption
```
FSQS ≥ 50 triggers **First-Session Recovery Playbook**.

---

## 7) Tutor Reliability Scoring (THS)
Rolling 7-day behavior:
```
− High tutor-initiated reschedule rate
− Recent no-shows
− Increasing lateness trend
− Low recent ratings
+ Quality recovery from recent sessions
```
Label thresholds:
- `<55` = high reliability risk
- `55–75` = monitor
- `>75` = stable

---

## 8) Tutor Churn Risk Scoring (TCRS)
Support-first behavioral withdrawal detection (14 days):
```
+0.4 if availability drops vs prior period
+0.3 if completed sessions drop significantly
+0.15 if tutor-initiated reschedules rise
+0.20 if any no-shows
+0.20 if repeat-student rate low
+0.20 if message response latency >12h
```
Interpretation:
- `≥0.6` → Support Check‑In
- `0.3–0.59` → Monitor
- `<0.3` → Stable

Purpose: **“We help tutors before they feel overwhelmed.”**

---

## 9) Interventions (Support-Oriented)

| Scenario | Trigger | Intervention |
|---|---|---|
| Low first session quality | FSQS ≥ 50 | Guided follow‑up script + senior tutor support option |
| High reschedule rate | THS reschedule component elevated | Calendar planning walkthrough + schedule reset help |
| No‑show risk | THS + lateness/no-show trend | T‑24/T‑2 confirmations + backup assignment |
| Churn risk | TCRS ≥ 0.6 | Coach check‑in call + workload adjustment + encouragement resources |

All interventions are logged to enable outcome tracking.

---

## 10) Architecture

```
DB Polling (every 5 min) → SessionScoringJob → SQS + FSQS → scores table
                                                           → AlertJob → alerts table

Sessions → TutorDailyAggregationJob (every 10 min) → tutor_daily_aggregates
                                                   → tutor_stats_7d (MV refresh)
                                                   → tutor_stats_14d (MV refresh)
                                                                    ↓
                                                          TutorHealthScoreJob → THS → scores
                                                          TutorChurnRiskScoreJob → TCRS → scores
```

### API Endpoints

**Tutor Dashboard (`/tutor/:id`)**
- `GET /api/tutor/:id/fsqs_latest` - Most recent FSQS with feedback
- `GET /api/tutor/:id/fsqs_history` - Last 5 first-sessions with FSQS
- `GET /api/tutor/:id/performance_summary` - AI-generated summary
- `GET /api/tutor/:id/session_list` - Recent sessions with SQS
- `GET /api/tutor/:id/sqs_actionable_feedback` - Actionable items based on last 10 SQS scores
- `POST /api/tutor/:id/ai_feedback` - Get AI-powered detailed feedback for specific actionable item (uses last 5 session transcripts)

**Admin Dashboard (`/admin/:id`)**
- `GET /api/admin/tutors/risk_list` - Sorted tutors with risk metrics
- `GET /api/admin/tutor/:id/metrics` - Full metrics breakdown
- `GET /api/admin/tutor/:id/fsqs_history` - FSQS history
- `GET /api/admin/tutor/:id/intervention_log` - Past interventions
- `POST /api/admin/alerts/:id/update_status` - Update alert status

### Background Jobs

| Job | Frequency | Purpose |
|-----|-----------|---------|
| SessionScoringJob | every 5 min | Compute SQS + FSQS on recent sessions |
| TutorDailyAggregationJob | every 10 min | Update daily aggregates |
| TutorHealthScoreJob | every 10 min | Compute THS from 7d window |
| TutorChurnRiskScoreJob | every 10 min | Compute TCRS from 14d window |
| AlertJob | every 10 min | Generate/resolve alerts based on thresholds (no duplicates - keeps existing alerts open if condition persists) |

End‑to‑insight SLA: ≤ 60 minutes.

---

## 11) Demo Requirements (MVP Build Scope)
- No authentication (route-based access)
- Seed data for 20–200 tutors w/ varying behaviors
- Tutor Dashboard UI + Admin Dashboard

### Tutor Detail Pane (when a tutor is clicked)
- **Header:** Tutor Name + Status Badges (Risk / Reliability / Churn)
- **Key Metrics Overview:**
  - **SQS Trend:** Sparkline of last N sessions
  - **FSQS Overview:** Last first-session score + Trend across students
  - **THS (7‑day Health Score):** Reliability & behavior score, with breakdown:
    - Reschedule Rate (7d)
    - Lateness Trend (7d)
    - No-Show Count (7d)
  - **TCRS (14‑day Churn Risk):** Engagement score, with breakdown:
    - Sessions_14d vs previous 14d
    - Availability_14d trend
    - Repeat Student Rate

- **Session Table:**
  | Date | Student | SQS | FSQS Tag | Notes |

- **First‑Session Feedback List:**
  Shows each FSQS case with link to transcript + suggestions.

- **Intervention Actions:** (log-only in MVP)
  - Assign coach
  - Mark outreach done
  - Add note

---

Admin Dashboard UI (`/admin/:id`)
- Risk overview table sorted by priority (Reschedule, No-Show, Churn)
- Tutor detail panels with:
  - SQS trend sparkline
  - FSQS trend across students
  - THS breakdown (7d metrics)
  - TCRS breakdown (14d metrics)
  - Session table with SQS/FSQS tags
  - First-session feedback list
- Alerts list with status management
- Intervention actions (log-only in MVP):
  - Assign coach
  - Mark outreach done
  - Add note
- API endpoints: See Architecture section above

---

## 12) Success Criteria
- Admin users can identify at-risk tutors with evidence
- Tutors view dashboard and understand **one clear improvement** step
- Coaches report alerts are actionable & supportive
- Time-to-flag ≤ 1 hour after session end

---

## 13) AI-Powered Detailed Feedback (Post-MVP Feature)

### Overview
Tutors can request AI-powered, contextual feedback on specific actionable items. The system analyzes the last 5 session transcripts using LLM to provide specific, moment-by-moment suggestions.

### User Flow
1. Tutor views Actionable Items section on dashboard
2. For each actionable item, a "Get AI Feedback" button is available
3. Clicking the button:
   - Sends last 5 session transcripts (with student names and timestamps) to LLM
   - Includes the actionable item context (e.g., "Use More Encouragement")
   - LLM analyzes transcripts and provides specific feedback
4. Feedback is displayed in a modal/expanded section with:
   - 2-3 specific moments where the issue occurred
   - Student name and session context for each moment
   - Exact suggestion (e.g., "When John finished question 5, you could have said 'Great job!'")
   - Why this would help

### Technical Implementation
- **Service**: `AIActionableFeedbackService`
- **Input**: Tutor ID, actionable item type (e.g., 'encouragement', 'confusion', 'goal_setting')
- **Process**:
  1. Fetch last 5 completed sessions with transcripts
  2. Extract transcripts with speaker diarization, student names, timestamps
  3. Construct prompt with:
     - Actionable item context
     - Transcript data
     - Instructions for specific, contextual feedback
  4. Call LLM API (OpenAI, Anthropic, etc.)
  5. Parse and return structured feedback
- **Output**: JSON with specific suggestions, moments, and context
- **Caching**: Results cached per tutor + actionable item for 24 hours
- **Rate Limiting**: Max 5 requests per tutor per day
- **Error Handling**: Fallback to generic feedback if LLM fails

### Example Prompt Structure
```
You are analyzing tutoring session transcripts to provide specific, actionable feedback.

Context:
- Actionable Item: "Use More Encouragement"
- Tutor has been flagged for not using encouragement phrases in recent sessions

Last 5 Session Transcripts:
[Insert transcripts with student names, timestamps, and speaker diarization]

Instructions:
1. Identify 2-3 specific moments across these sessions where the tutor should have used encouragement
2. For each moment, provide:
   - Student name
   - Session date/time
   - What the student did/said
   - Specific encouragement phrase that would have been appropriate
   - Why this would help
3. Format as a clear, actionable list
```

### Benefits
- **More actionable**: Specific moments vs. generic tips
- **Personalized**: References actual students and sessions
- **Contextual**: Uses actual conversation content
- **Better learning**: Tutors see exactly what to change

## 14) Out-of-Scope (Post-MVP)
- ML prediction models
- Automatic scheduling adjustments
- Gamification in tutor dashboard
- Cross-platform messaging automations

---

End of PRD.


## Data Contracts & MVP Assumptions
- **FSQS requires diarized transcripts.** If speaker labels are not available, FSQS is **not computed** for that session (SQS still applies).
- **Student confusion detection** uses a dictionary-based approach on *student* turns. Threshold: **≥ 3 confusion phrases** → FSQS +20.
- **Tutor churn (MVP definition):** A tutor is considered churned only when they are **explicitly deactivated**. (No inactivity-based churn in MVP.)
- **Message response latency** is **post‑MVP** and excluded from TCRS v1.
- **SQS applies to every completed session.**
- **FSQS applies only to a tutor’s first session with a specific student.**
  - Implementation detail: mark `first_session_for_student` = true when `(tutor_id, student_id)` pair appears for the **first time**.
- **Ingestion method (MVP):** DB polling every 5–10 minutes for new/updated sessions.
- **Event bus integration** is **post‑MVP**.
- **Admin action workflows** are internal only (update alert state + coaching notes, with optional link‑outs). No external scheduling or automation triggered in MVP.


## Update: Removal of Student Rating Input (MVP Adjustment)
- Student-provided session ratings will **not** be collected or used in MVP.
- **SQS formula is updated** to remove the rating adjustment component.

### Revised SQS (Session Quality Score v1)
```
base = 80
- lateness_penalty = min(20, 2 * lateness_min)
- shortfall_penalty = min(10, 1 * end_shortfall_min)
- tech_penalty = 10 if tech_issue else 0

SQS = clamp(0, 100, base - lateness_penalty - shortfall_penalty - tech_penalty)

label:
  risk if SQS < 60
  warn if 60–75
  ok if >75
```

### FSQS (First Session Quality Score) Impact
- FSQS remains the same **except** the rating-based trigger is removed.
- Confusion, structure, sentiment, and reinforcement cues remain.

### Tutor Health Score (THS) Impact
- THS previously used rating-based penalties.
- Rating contribution is now removed — **lateness, reschedules, no-shows remain primary drivers**.


## Rolling Window Data Flow
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

This clarifies:
- **7-Day metrics** detect short-term operational risks (reschedules, no-shows, lateness).
- **14-Day metrics** detect medium-term disengagement (withdrawal → churn).

Both feed into dashboards, but address **different problems**.


## Clarifications on Session Experience Signals (No Fault Attribution)
- **Lateness**, **ending early**, and **tech issues** are treated as **session experience signals**, not tutor blame.
- These signals affect **SQS (Session Quality Score)** and **FSQS (First‑Session Risk Score)** because they change the *student experience*.
- These signals **do not reduce THS (Tutor Health Score)** unless the pattern is repeated and clearly behavioral (e.g., repeated tutor‑initiated lateness or no‑shows).

### Updated Interpretations
| Signal | Source | Affects | Why |
|-------|--------|--------|-----|
| **Lateness** | scheduled vs actual start timestamps | SQS / FSQS only | Students experience disruption regardless of cause |
| **Ending Early** | scheduled vs actual session duration | SQS only | Indicates pacing issue, not intent |
| **Tech Issues** | simple session-level tech flag | SQS / FSQS only | Disruption matters, but fault is unknown |
| **Tutor No‑Show** | explicit session status | THS & Alerts | Clear, attributable reliability failure |
| **Tutor‑Initiated Reschedule** | reschedule_initiator = 'tutor' | THS & Alerts | Clear tutor behavior signal |

### Final Rule
> **We score what the student experienced, not who is at fault.**

This ensures the system is:
- Fair to tutors
- Aligned to student retention goals
- Easy to explain


## Assumptions (Data & System Inputs)
- **Transcript Availability**: Session transcripts are available in a structured format with speaker diarization (tutor vs student). If diarization is absent for a session, **FSQS is not computed**.
- **Timing Metadata**: `scheduled_start_at`, `actual_start_at`, `scheduled_end_at`, and `actual_end_at` timestamps are reliably captured to derive lateness and session duration.
- **Tech Issue Flag**: A binary `tech_issue` indicator is available per session (source-agnostic, no blame attribution).
- **Session Identification**: We can reliably detect when a session is a **first session between a tutor and a student** (via absence of prior sessions in DB).
- **Tutor Churn Definition**: Churn is defined as **tutor deactivation** (not inactivity window) for the MVP.
- **Message Latency Data**: Not required for MVP; may be included post‑MVP.
- **Event Delivery**: MVP uses **DB polling** for new/updated sessions; event bus integration is **post‑MVP**.
- **Intervention Execution**: Coach/Admin actions are **logged internally only** (no automated scheduling or messaging changes in MVP).

