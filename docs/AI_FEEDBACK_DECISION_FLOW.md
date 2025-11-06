# How AI-Powered Feedback Decision Flow Works

## Overview

The AI-powered feedback system uses a **two-stage approach**:

1. **Stage 1: Identify Issues** - Analyze SQS scores to find problems
2. **Stage 2: Generate Detailed Feedback** - Use AI to provide specific suggestions for each issue

---

## Stage 1: Identifying What to Show (SqsActionableFeedbackService)

### Step 1: Analyze Last 5 Sessions

```ruby
# Get last 5 SQS scores (ordered by session date)
sqs_scores = Score.where(tutor: @tutor, score_type: 'sqs')
  .joins(:session)
  .order('sessions.scheduled_start_at DESC')
  .limit(5)
```

### Step 2: Count Deductions

The system analyzes each SQS score's `components` to count how many times each issue occurred:

**Transcript-Based Issues:**
- `confusion_phrases` → Count sessions with confusion
- `word_share_imbalance` → Count sessions where tutor spoke >75%
- `missing_goal_setting` → Count sessions without early goal-setting
- `missing_encouragement` → Count sessions without encouragement phrases
- `missing_closing_summary` → Count sessions without closing summary
- `negative_phrasing` → Count sessions with negative phrasing

**Operational Issues:**
- `lateness_penalty` → Count late sessions + average lateness
- `shortfall_penalty` → Count early endings + average shortfall
- `tech_penalty` → Count sessions with tech issues

### Step 3: Generate Actionable Items

**Decision Logic:**

```ruby
# Show item if it occurred in ANY of the last 5 sessions
if deductions[:confusion_count] > 0
  items << {
    type: 'confusion',
    priority: deductions[:confusion_count] >= 5 ? 'high' : 'medium',
    # ... item details
  }
end
```

**Priority Rules:**
- **High Priority**: Issue occurred in 5/5 sessions (or 3+ for tech issues)
- **Medium Priority**: Issue occurred in 1-4 sessions
- Items are sorted: High priority first, then by type

**What Gets Displayed:**
- All items where `count > 0` are shown
- No limit on number of items (could show all 9 types if all occurred)
- Items sorted by priority (high → medium) then alphabetically

### Step 4: Show Generic Feedback

Each actionable item includes:
- **Title**: "Address Student Confusion"
- **Description**: "Students expressed confusion in 3 out of 5 recent sessions."
- **Action**: Generic advice ("When you notice confusion phrases...")

---

## Stage 2: AI-Powered Detailed Feedback (AiActionableFeedbackService)

### Step 1: User Clicks "Get AI Feedback" Button

```jsx
// Frontend: User clicks button
onClick={() => handleGetAIFeedback(item.type)}
```

The `item.type` is passed to the API (e.g., `'confusion'`, `'word_share'`, `'lateness'`).

### Step 2: Check Cache & Rate Limits

```ruby
# Check if already cached (24-hour cache)
cached = get_cached_feedback
return cached if cached

# Check rate limit (5 requests per day)
unless check_rate_limit
  return { error: 'rate_limit_exceeded' }
end
```

### Step 3: Fetch Last 5 Sessions with Transcripts

```ruby
sessions = Session.where(tutor: @tutor, status: 'completed')
  .joins(:session_transcript)  # Must have transcript
  .order('sessions.scheduled_start_at DESC')
  .limit(5)
```

**Requirements:**
- Must have at least 5 completed sessions
- All sessions must have transcripts
- If < 5 sessions → return error

### Step 4: Build Context-Specific Prompt

The prompt is customized based on the `actionable_item_type`:

```ruby
actionable_item_context = get_actionable_item_context
# Returns context like:
# {
#   title: 'Address Student Confusion',
#   description: 'Students expressed confusion in recent sessions...'
# }
```

**Prompt Structure:**
```
Context:
- Actionable Item: [Title from SqsActionableFeedbackService]
- Issue: [Description from SqsActionableFeedbackService]

Last 5 Session Transcripts:
[Formatted transcripts with student names, dates, times, speaker diarization]

Instructions:
1. Identify 2-3 specific moments where the tutor should have addressed [issue]
2. For each moment, provide:
   - Student name
   - Session date/time
   - What was happening (context)
   - Specific phrase/action that would help
   - Why this would help
```

### Step 5: Call OpenAI API

```ruby
response = call_openai(prompt)
# Uses GPT-4o-mini
# Temperature: 0.7
# Max tokens: 1000
```

### Step 6: Parse & Return Response

```ruby
feedback = parse_response(response)
# Returns:
# {
#   actionable_item_type: 'confusion',
#   moments: [
#     {
#       student_name: "John",
#       session_date: "2025-11-05",
#       session_time: "3:00 PM",
#       context: "When John said 'I don't understand problem 5'...",
#       suggestion: "You could have asked 'What specific part is confusing?'",
#       reason: "This helps identify the exact area of confusion..."
#     }
#   ]
# }
```

### Step 7: Fallback if AI Fails

If OpenAI API fails or returns invalid JSON:
```ruby
get_fallback_feedback
# Returns generic feedback based on actionable_item_type
# Does NOT use actual session transcripts
```

---

## Decision Flow Summary

```
┌─────────────────────────────────────────┐
│ 1. Load Dashboard                       │
│    → Fetch SQS Actionable Feedback      │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│ 2. SqsActionableFeedbackService         │
│    → Analyze last 5 SQS scores          │
│    → Count deductions per issue type    │
│    → Generate actionable items          │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│ 3. Display Items                        │
│    → Show all items with count > 0      │
│    → Sort by priority (high → medium)   │
│    → Each item has "Get AI Feedback"    │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│ 4. User Clicks "Get AI Feedback"        │
│    → Passes item.type to API            │
│    → e.g., 'confusion', 'word_share'    │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│ 5. AiActionableFeedbackService          │
│    → Check cache (24h TTL)              │
│    → Check rate limit (5/day)            │
│    → Fetch last 5 sessions + transcripts│
│    → Build context-specific prompt      │
│    → Call OpenAI API                     │
│    → Parse JSON response                │
│    → Return 2-3 specific moments        │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│ 6. Display AI Feedback                  │
│    → Show specific moments               │
│    → With student names, dates, context  │
│    → Specific suggestions                │
└─────────────────────────────────────────┘
```

---

## Key Decision Points

### 1. Which Items to Show?

**Criteria:**
- Issue occurred in **at least 1 of last 5 sessions**
- Based on SQS score `components` (penalties > 0)

**No Filtering:**
- All items with `count > 0` are shown
- Could show 1 item or all 9 items
- No maximum limit

### 2. Priority Assignment?

**High Priority:**
- Issue occurred in **5/5 sessions** (100% occurrence)
- OR **3+ sessions** for tech issues

**Medium Priority:**
- Issue occurred in **1-4 sessions**

### 3. When to Show AI Feedback?

**User-Initiated:**
- Only when user clicks "Get AI Feedback" button
- Not automatic
- Requires active user action

**Requirements:**
- Must have 5+ completed sessions with transcripts
- Must not exceed rate limit (5 requests/day)
- Must have transcript data available

### 4. What AI Feedback Shows?

**Content:**
- 2-3 specific moments from actual session transcripts
- References real students by name
- Includes actual session dates/times
- Provides specific phrases to use
- Explains why each suggestion helps

**Fallback:**
- Generic advice if AI fails
- No student names or specific moments
- Template-based suggestions

---

## Current Limitations

1. **No Prioritization**: Shows ALL items with `count > 0` (could be overwhelming)

2. **No Filtering**: Doesn't filter out resolved issues or low-impact items

3. **No Contextual Decisions**: Doesn't consider:
   - Tutor's improvement history
   - Severity of deductions (small vs. large penalties)
   - Time since last feedback
   - User preferences

4. **Fixed Window**: Always analyzes last 5 sessions (not adaptive)

5. **No AI Selection**: AI feedback is user-initiated, not automatically suggested

---

## Potential Improvements

### 1. Smart Filtering
- Only show items with significant impact (e.g., >10 point deduction)
- Hide items that have improved recently
- Prioritize items that haven't been addressed

### 2. Automatic AI Suggestions
- Automatically generate AI feedback for high-priority items
- Show AI feedback as default, not requiring button click

### 3. Adaptive Windows
- Use longer window (10 sessions) for tutors with more history
- Use shorter window (3 sessions) for new tutors

### 4. Contextual Prioritization
- Consider tutor's improvement trajectory
- Weight recent sessions more heavily
- Consider severity of deductions (not just count)

### 5. Personalization
- Learn which feedback types tutors find most helpful
- Prioritize items based on user feedback history

---

## Example Flow

**Scenario: Tutor has lateness and confusion issues**

1. **SQS Analysis:**
   - Last 5 sessions analyzed
   - `lateness_count = 3` (late in 3 sessions)
   - `confusion_count = 2` (confusion in 2 sessions)

2. **Items Generated:**
   - Item 1: "Start Sessions on Time" (priority: medium, count: 3)
   - Item 2: "Address Student Confusion" (priority: medium, count: 2)

3. **Both Items Displayed:**
   - Both shown on dashboard
   - Sorted by priority (both medium, sorted alphabetically)
   - Each has "Get AI Feedback" button

4. **User Clicks on "Address Student Confusion":**
   - API receives `actionable_item_type: 'confusion'`
   - Fetches last 5 sessions with transcripts
   - Builds prompt focused on confusion moments
   - AI analyzes transcripts and finds 2-3 specific moments where confusion occurred
   - Returns feedback with student names, dates, and specific suggestions

5. **AI Feedback Displayed:**
   - Shows specific moments from transcripts
   - "When Sarah said 'I don't understand' on Nov 5 at 3pm..."
   - "You could have asked 'What part is confusing?'"
   - Much more specific than generic action item

---

## Summary

**Current System:**
- **What to show**: All issues found in last 5 sessions (any count > 0)
- **When to show**: Always on dashboard load
- **AI feedback**: User-initiated, on-demand, for specific item type
- **Priority**: Based on frequency (5/5 = high, 1-4 = medium)

**Decision Logic:**
1. Count issues from SQS components
2. Generate items for any issue with count > 0
3. User decides which item to get AI feedback for
4. AI analyzes transcripts and provides specific moments

