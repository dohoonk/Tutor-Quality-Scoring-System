# Transcript Quotes Feature

## Overview

The AI-powered feedback system now returns **exact transcript quotes** from the actual session transcripts, making feedback more concrete and actionable for tutors.

## What Changed

### Before
- AI feedback provided generic descriptions of moments
- No direct quotes from transcripts
- Less concrete and harder to verify

### After
- AI feedback includes **exact transcript quotes** with timestamps
- Quotes are verified against actual transcript data
- Surrounding context automatically included
- Visual distinction between verified and AI-generated quotes

## Implementation Details

### Backend Changes

#### 1. Updated Prompt (`AiActionableFeedbackService`)

The AI prompt now explicitly requests transcript quotes:

```ruby
"transcript_quotes": [
  {
    "speaker": "student",
    "text": "Exact quoted text from transcript",
    "timestamp": "00:05:23"
  }
]
```

#### 2. Quote Verification System

- **Exact Matching**: Verifies AI-provided quotes against actual transcript
- **Fuzzy Matching**: If exact match fails, tries partial text matching
- **Context Addition**: Automatically adds 2-3 quotes before and after the key moment

#### 3. Automatic Quote Extraction

If AI doesn't provide quotes, the system:
- Extracts keywords from context/suggestion
- Finds relevant moments in transcript
- Includes surrounding context automatically

### Frontend Changes

#### Display Format

Transcript quotes are displayed in a dedicated section:

```
📝 Exact Transcript:
  Student [00:05:23]: "I don't understand this problem"
  Tutor [00:05:30]: "Let's look at it step by step"
  Student [00:05:45]: "Okay, I think I see it now"
```

#### Visual Features

- **Color Coding**: 
  - Tutor quotes in blue
  - Student quotes in green
- **Context Quotes**: Shown in italic with reduced opacity
- **Verification Badge**: Shows "(AI-generated)" if quote couldn't be verified
- **Timestamps**: Displayed for each quote

## Response Structure

### New JSON Response Format

```json
{
  "actionable_item_type": "confusion",
  "moments": [
    {
      "student_name": "Sarah",
      "session_date": "2025-11-05",
      "session_time": "3:00 PM",
      "transcript_quotes": [
        {
          "speaker": "student",
          "text": "I don't understand this problem at all",
          "timestamp": "00:05:23",
          "verified": true,
          "is_context": false
        },
        {
          "speaker": "tutor",
          "text": "Let's break it down step by step",
          "timestamp": "00:05:30",
          "verified": true,
          "is_context": false
        },
        {
          "speaker": "student",
          "text": "Okay, I think I see it now",
          "timestamp": "00:05:45",
          "verified": true,
          "is_context": true
        }
      ],
      "context": "Sarah expressed confusion about problem 5",
      "suggestion": "You could have asked 'What specific part is confusing?'",
      "reason": "This helps identify the exact area of confusion"
    }
  ]
}
```

## Features

### 1. Quote Verification

- **Verified Quotes**: Exact matches from transcript (marked `verified: true`)
- **Fuzzy Matches**: Partial text matches (also `verified: true`)
- **AI-Generated**: Couldn't match to transcript (marked `verified: false`)

### 2. Context Addition

Automatically includes:
- 2 quotes before the key moment
- 2 quotes after the key moment
- Marked with `is_context: true` for visual distinction

### 3. Automatic Extraction

If AI doesn't provide quotes:
- Extracts keywords from context/suggestion
- Finds relevant moments in transcript
- Includes surrounding context

## Benefits

1. **More Concrete**: Tutors see exact words from their sessions
2. **Verifiable**: Quotes are matched against actual transcripts
3. **Better Context**: Surrounding quotes provide full picture
4. **Actionable**: Easier to understand what happened and what to change

## Example

### Before:
```
Context: Student expressed confusion
Suggestion: Ask clarifying questions
```

### After:
```
📝 Exact Transcript:
  Student [00:05:23]: "I don't understand this problem at all"
  Tutor [00:05:30]: "Let's break it down step by step"
  Student [00:05:45]: "Okay, I think I see it now" (context)

Context: Sarah expressed confusion about problem 5
💡 Suggestion: "You could have asked 'What specific part is confusing?'"
Why: This helps identify the exact area of confusion
```

## Technical Details

### Token Limit

Increased from 1000 to 2000 tokens to accommodate transcript quotes.

### Matching Logic

1. **Exact Match**: Speaker + exact text + timestamp
2. **Fuzzy Match**: Speaker + partial text match
3. **Fallback**: Use AI's version, mark as unverified

### Performance

- Quote verification is fast (in-memory matching)
- No additional database queries
- Context addition adds minimal overhead

## Future Enhancements

1. **Quote Highlighting**: Highlight specific words/phrases in quotes
2. **Full Transcript View**: Link to view full session transcript
3. **Quote Search**: Search for specific moments across sessions
4. **Audio Timestamps**: Link quotes to audio playback (if available)

