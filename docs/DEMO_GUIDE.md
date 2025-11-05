# Demo Guide - Tutor Quality Scoring System

This guide provides narrative data profiles and demo scenarios to showcase the Tutor Quality Scoring System effectively.

## Demo Setup

### Prerequisites
1. **Start the application:**
   ```bash
   cd tutor-insights
   bin/dev
   ```

2. **Load demo profiles:**
   ```bash
   rails runner db/seeds/demo_profiles.rb
   ```

3. **Note the Demo Tutor IDs** (displayed after running the seed script)

---

## Demo Profiles

We've created four narrative profiles that tell compelling stories:

### 1. **Sarah Excellence** - The Gold Standard 🌟
**Profile:** Strong, consistent tutor with excellent metrics across the board

**Key Stats:**
- **SQS Average:** 98/100 (Excellent)
- **FSQS:** 0 (Perfect first sessions)
- **THS:** 95/100 (Highly reliable)
- **TCRS:** 0.15 (Very stable, no churn risk)
- **Sessions:** 20 in last 2 weeks
- **Alerts:** None

**Story:** Sarah is the benchmark. Always on time, completes full sessions, no technical issues, and her first sessions are textbook perfect with goal-setting, encouragement, and clear summaries.

**Demo URL:** `http://localhost:3000/tutor/[Sarah's ID]`

**What to Show:**
- ✅ Consistent high SQS scores in the trend
- ✅ Perfect FSQS feedback: "What went well" highlights all positives
- ✅ Performance summary shows "Excellent consistency!"
- ✅ All sessions green in the recent sessions table

---

### 2. **James Improving** - The Growth Story 📈
**Profile:** Tutor showing clear improvement trend

**Key Stats:**
- **SQS Trend:** Started at 65, now at 85 (Improving!)
- **FSQS:** 35 (Some early issues, but improving)
- **THS:** 72/100 (Monitor - getting better)
- **TCRS:** 0.35 (Stable)
- **Sessions:** 15 in last 2 weeks
- **Alerts:** None currently

**Story:** James started rough - late to sessions, cutting them short, some tech issues. But he's clearly learning and improving. His recent sessions are much better, showing the positive impact of coaching.

**Demo URL:** `http://localhost:3000/tutor/[James's ID]`

**What to Show:**
- ✅ Clear upward trend in SQS sparkline
- ✅ Performance summary: "Great progress! Your session quality has been improving consistently"
- ✅ FSQS feedback shows some areas to work on, but improving
- ✅ Recent sessions show higher scores than earlier ones
- ✅ Perfect example of coaching working

---

### 3. **Maria Declining** - The Intervention Needed 📉
**Profile:** Previously strong tutor who's slipping - needs attention

**Key Stats:**
- **SQS Trend:** Started at 88, now at 64 (Declining!)
- **FSQS:** 55 (High Risk - **ALERT TRIGGERED**)
- **THS:** 48/100 (High Risk)
- **TCRS:** 0.52 (Monitor - concerning)
- **Sessions:** 15 in last 2 weeks
- **Alerts:** 1 open alert (Poor First Session)

**Story:** Maria used to be great, but something's changed. Increasingly late, ending sessions early, recent first session had multiple red flags (confusion, missing goal-setting, abrupt ending). This is exactly who the system is designed to catch.

**Demo URL:** `http://localhost:3000/tutor/[Maria's ID]`

**What to Show:**
- ⚠️ Clear downward trend in SQS sparkline
- ⚠️ FSQS shows HIGH RISK with red indicator
- ⚠️ Performance summary acknowledges the dip but remains supportive
- ⚠️ Admin dashboard shows Maria with **red status badges**
- ⚠️ Alert count shows "1 open" in admin view
- 🎯 **This is the money shot** - shows the system catching at-risk tutors

---

### 4. **Alex ChurnRisk** - The Disengagement Pattern 🚨
**Profile:** Low engagement, inconsistent, high churn risk

**Key Stats:**
- **SQS Average:** 68 (Mediocre, inconsistent)
- **FSQS:** 45 (Warning level)
- **THS:** 52/100 (High Risk)
- **TCRS:** 0.72 (High Churn Risk - **ALERT TRIGGERED**)
- **Sessions:** Only 8 in last 2 weeks (low engagement)
- **Alerts:** 2 open alerts (Churn Risk + High Reliability Risk)

**Story:** Alex is showing classic disengagement patterns - irregular schedule, mediocre performance, low session count. The system has flagged for potential churn before it's too late.

**Demo URL:** `http://localhost:3000/tutor/[Alex's ID]`

**What to Show:**
- 🚨 Multiple red/yellow status badges
- 🚨 TCRS score of 0.72 with red "High Risk" indicator
- 🚨 Admin dashboard shows **2 open alerts**
- 🚨 Sparse session history shows engagement issues
- 🎯 Demonstrates early churn prediction

---

## Demo Walk-Through Scenarios

### Scenario 1: "The Weekly Admin Review" (5 minutes)

**Objective:** Show how an admin quickly identifies and prioritizes at-risk tutors

**Steps:**

1. **Open Admin Dashboard:**
   ```
   http://localhost:3000/admin/1
   ```

2. **Explain the Risk Overview Table:**
   - "This table shows all tutors sorted by risk level"
   - "Notice how Maria and Alex are at the top - they need attention"
   - "Status badges give quick visual indicators"

3. **Click "View Details" on Maria Declining:**
   - "Maria used to be great - SQS was 88"
   - "But look at this declining trend (point to sparkline)"
   - "She triggered an alert on her recent first session"
   - "FSQS of 55 means something went wrong - maybe confusion, missing goal-setting"

4. **Show the intervention workflow:**
   - "The system already flagged this"
   - "An admin can now reach out to Maria proactively"
   - "Before students start leaving or leaving bad reviews"

5. **Click "View Details" on Alex ChurnRisk:**
   - "Alex shows a different pattern - disengagement"
   - "Only 8 sessions in 2 weeks, irregular schedule"
   - "TCRS of 0.72 predicts churn risk"
   - "We can intervene now, maybe adjust scheduling or provide support"

**Key Points:**
- ✅ Proactive vs reactive
- ✅ Data-driven coaching
- ✅ Catch issues before they escalate

---

### Scenario 2: "The Tutor's Self-Reflection" (3 minutes)

**Objective:** Show how tutors get actionable feedback

**Steps:**

1. **Open James's Tutor Dashboard:**
   ```
   http://localhost:3000/tutor/[James's ID]
   ```

2. **Walk through the feedback:**
   - "James can see his improvement trend"
   - "'Great progress! Your session quality has been improving'"
   - "What went well: 'You're showing solid fundamentals'"
   - "One improvement: 'Focus on consistency - start on time'"

3. **Show FSQS section:**
   - "For his first session, some areas to improve"
   - "But the feedback is constructive, not punitive"
   - "Specific, actionable suggestions"

4. **Show Sarah's dashboard for contrast:**
   ```
   http://localhost:3000/tutor/[Sarah's ID]
   ```
   - "'Excellent consistency!'"
   - "Positive reinforcement for doing things right"

**Key Points:**
- ✅ Supportive, not punitive
- ✅ Specific, actionable feedback
- ✅ Celebrates what's working

---

### Scenario 3: "The Background Intelligence" (2 minutes)

**Objective:** Show the automated scoring and alerting system

**Steps:**

1. **Open Sidekiq Dashboard:**
   ```
   http://localhost:3000/sidekiq
   ```

2. **Explain the jobs:**
   - "SessionScoringJob runs every 5 minutes"
   - "Analyzes 3,000 sessions, computes SQS and FSQS"
   - "AlertJob runs every 10 minutes"
   - "Checks thresholds, creates alerts, auto-resolves when conditions improve"

3. **Show the scalability:**
   - "Handles 3,000 daily sessions"
   - "All processing within 1 hour requirement"
   - "No manual review needed for scoring"

4. **Explain the thresholds:**
   - "FSQS ≥50 = Alert for poor first session"
   - "THS <55 = High reliability risk"
   - "TCRS ≥0.6 = Churn risk"
   - "System prevents duplicate alerts"
   - "Auto-resolves when tutors improve"

**Key Points:**
- ✅ Fully automated
- ✅ Scales to thousands of sessions
- ✅ Intelligent alert management

---

## Demo Tips

### Opening Line
"We built a system that turns 3,000 daily tutoring sessions into actionable insights - automatically identifying at-risk tutors before problems escalate."

### Key Messages
1. **Proactive, not reactive** - Catch issues before students complain
2. **Data-driven coaching** - Specific feedback, not vague suggestions
3. **Supportive approach** - Helps tutors improve, doesn't punish
4. **Fully automated** - Scales without adding admin overhead
5. **Early intervention** - Catch declining performance and churn risk early

### Common Questions & Answers

**Q: How accurate are the scores?**
A: The system uses objective metrics (timing, duration, tech issues) for SQS. FSQS analyzes actual transcripts for specific patterns like goal-setting and encouragement. It's based on real data, not subjective reviews.

**Q: Won't this stress out tutors?**
A: The feedback is designed to be supportive and actionable. Look at James's dashboard - it celebrates his improvement. Even declining tutors get encouraging language with specific suggestions.

**Q: What if a tutor disagrees with their score?**
A: Scores come with detailed breakdowns. For FSQS, tutors can see exactly what patterns were detected (e.g., "missing goal-setting question"). It's transparent and specific.

**Q: How do you prevent alert fatigue?**
A: The system prevents duplicate alerts - if Maria already has an alert open, it won't create another one. Alerts auto-resolve when conditions improve. Only one open alert per type per tutor.

**Q: Can this scale?**
A: Yes! Background jobs process in batches. Current setup handles 3,000 sessions within 1 hour. Can scale horizontally with more Sidekiq workers.

---

## Quick Demo Commands

```bash
# Load demo profiles
rails runner db/seeds/demo_profiles.rb

# Open Admin Dashboard
open http://localhost:3000/admin/1

# Open specific tutor dashboards
open http://localhost:3000/tutor/11  # Sarah Excellence
open http://localhost:3000/tutor/12  # James Improving
open http://localhost:3000/tutor/13  # Maria Declining
open http://localhost:3000/tutor/14  # Alex ChurnRisk

# View Sidekiq jobs
open http://localhost:3000/sidekiq

# Check background job status
rails console
> SessionScoringJob.new.perform  # Run scoring manually
> AlertJob.new.perform           # Run alert evaluation manually
```

---

## The Punchline

**Before this system:**
- Admins react to student complaints
- No visibility into first-session quality
- Tutors leave without warning
- Coaching is generic and inconsistent

**After this system:**
- Proactive intervention before issues escalate
- Every first session analyzed for quality patterns
- Churn risk detected 14 days in advance
- Data-driven, specific coaching for each tutor

**Bottom line:** Transform 3,000 daily sessions into a competitive advantage.

