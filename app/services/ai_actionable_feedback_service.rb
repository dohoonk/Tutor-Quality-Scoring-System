# frozen_string_literal: true

class AiActionableFeedbackService
  RATE_LIMIT_PER_DAY = 5
  CACHE_EXPIRY = 24.hours

  def initialize(tutor, actionable_item_type)
    @tutor = tutor
    @actionable_item_type = actionable_item_type
  end

  def generate_feedback
    # Check cache first
    cached = get_cached_feedback
    return cached if cached

    # Check rate limit
    unless check_rate_limit
      return { error: 'rate_limit_exceeded', message: 'You have reached the daily limit of 5 AI feedback requests. Please try again tomorrow.' }
    end

    # Fetch sessions
    sessions = fetch_sessions
    return { error: 'insufficient_sessions', message: 'We need at least 5 completed sessions with transcripts to generate AI feedback.' } if sessions.length < 5

    # Extract transcript data
    transcript_data = extract_transcript_data(sessions)

    # Generate prompt
    prompt = build_prompt(transcript_data)

    # Call LLM
    begin
      response = call_openai(prompt)
      feedback = parse_response(response)
      
      # Cache the result
      cache_feedback(feedback)
      
      # Increment rate limit counter
      increment_rate_limit
      
      feedback
    rescue StandardError => e
      Rails.logger.error("AIActionableFeedbackService error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      
      # Return fallback feedback
      get_fallback_feedback
    end
  end

  def get_cached_feedback
    Rails.cache.read(cache_key)
  end

  def check_rate_limit
    count = Rails.cache.read(rate_limit_key) || 0
    count < RATE_LIMIT_PER_DAY
  end

  private

  def fetch_sessions
    Session.where(tutor: @tutor, status: 'completed')
           .joins(:session_transcript)
           .order('sessions.scheduled_start_at DESC')
           .limit(5)
           .includes(:session_transcript, :student)
  end

  def extract_transcript_data(sessions)
    sessions.map do |session|
      transcript = session.session_transcript.payload
      {
        student_name: session.student.name,
        session_date: session.scheduled_start_at.strftime('%Y-%m-%d'),
        session_time: session.scheduled_start_at.strftime('%I:%M %p'),
        speakers: transcript['speakers'] || [],
        metadata: transcript['metadata'] || {}
      }
    end
  end

  def build_prompt(transcript_data)
    actionable_item_context = get_actionable_item_context
    
    prompt = <<~PROMPT
      You are analyzing tutoring session transcripts to provide specific, actionable feedback for a tutor.

      Context:
      - Actionable Item: #{actionable_item_context[:title]}
      - Issue: #{actionable_item_context[:description]}

      Last 5 Session Transcripts:
      #{format_transcripts_for_prompt(transcript_data)}

      Instructions:
      1. Identify 2-3 specific moments across these sessions where the tutor should have addressed the issue (#{actionable_item_context[:title]}).
      2. For each moment, provide:
         - Student name
         - Session date/time
         - What the student did/said (or what was happening)
         - Specific phrase or action that would have been appropriate
         - Why this would help the student
      3. Format your response as valid JSON with this structure:
      {
        "moments": [
          {
            "student_name": "Student Name",
            "session_date": "YYYY-MM-DD",
            "session_time": "HH:MM AM/PM",
            "context": "What was happening at this moment",
            "suggestion": "Specific phrase or action",
            "reason": "Why this would help"
          }
        ]
      }

      Be specific and reference actual content from the transcripts. Focus on moments where the tutor could have improved based on the actionable item.
    PROMPT

    prompt
  end

  def format_transcripts_for_prompt(transcript_data)
    transcript_data.map do |data|
      speakers_text = data[:speakers].map do |speaker|
        "[#{speaker['timestamp']}] #{speaker['speaker'].capitalize}: #{speaker['text']}"
      end.join("\n")

      <<~TRANSCRIPT
        Session with #{data[:student_name]} on #{data[:session_date]} at #{data[:session_time]}:
        #{speakers_text}
        ---
      TRANSCRIPT
    end.join("\n\n")
  end

  def get_actionable_item_context
    contexts = {
      'encouragement' => {
        title: 'Use More Encouragement',
        description: 'The tutor has been flagged for not using encouragement phrases in recent sessions.'
      },
      'confusion' => {
        title: 'Address Student Confusion',
        description: 'Students expressed confusion in recent sessions and the tutor should address it more effectively.'
      },
      'word_share' => {
        title: 'Balance Conversation',
        description: 'The tutor spoke more than 75% of the time in recent sessions, creating an imbalance.'
      },
      'goal_setting' => {
        title: 'Set Goals Early',
        description: 'The tutor did not ask about goals in the first few minutes of recent sessions.'
      },
      'closing_summary' => {
        title: 'Summarize at the End',
        description: 'The tutor did not provide a summary or next steps at the end of recent sessions.'
      },
      'negative_phrasing' => {
        title: 'Use Positive Language',
        description: 'Negative phrasing was detected in recent sessions.'
      },
      'lateness' => {
        title: 'Start Sessions on Time',
        description: 'The tutor was late to recent sessions.'
      },
      'shortfall' => {
        title: 'Complete Full Session Duration',
        description: 'The tutor ended sessions early in recent sessions.'
      },
      'tech_issue' => {
        title: 'Resolve Technical Issues',
        description: 'The tutor experienced technical issues in recent sessions.'
      }
    }

    contexts[@actionable_item_type] || {
      title: 'Improve Session Quality',
      description: 'The tutor has areas for improvement in recent sessions.'
    }
  end

  def call_openai(prompt)
    client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
    
    response = client.chat(
      parameters: {
        model: 'gpt-4o-mini', # Using cheaper model for MVP
        messages: [
          {
            role: 'system',
            content: 'You are a helpful tutor coach. You analyze session transcripts and provide specific, actionable feedback. Always respond with valid JSON.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 1000
      }
    )

    response.dig('choices', 0, 'message', 'content')
  rescue OpenAI::Error => e
    Rails.logger.error("OpenAI API error: #{e.message}")
    raise
  end

  def parse_response(response_text)
    # Try to extract JSON from response
    json_match = response_text.match(/\{[\s\S]*\}/)
    if json_match
      parsed = JSON.parse(json_match[0])
      {
        actionable_item_type: @actionable_item_type,
        moments: parsed['moments'] || [],
        cached: false
      }
    else
      # Fallback if JSON parsing fails
      get_fallback_feedback
    end
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse OpenAI response: #{e.message}")
    get_fallback_feedback
  end

  def get_fallback_feedback
    fallback_messages = {
      'encouragement' => {
        moments: [
          {
            student_name: 'Your students',
            context: 'When students complete problems or answer questions correctly',
            suggestion: 'Use phrases like "Great job!", "Excellent work!", or "You are doing well!"',
            reason: 'This builds student confidence and encourages continued engagement'
          }
        ]
      },
      'confusion' => {
        moments: [
          {
            student_name: 'Your students',
            context: 'When students express confusion or say "I do not understand"',
            suggestion: 'Ask "What part would you like me to explain differently?" and pause to let them process',
            reason: 'This helps identify specific areas of confusion and shows you care about their understanding'
          }
        ]
      },
      'word_share' => {
        moments: [
          {
            student_name: 'Your students',
            context: 'Throughout the session',
            suggestion: 'Ask open-ended questions and give students time to think before responding',
            reason: 'This creates a better learning environment where students actively participate'
          }
        ]
      },
      'goal_setting' => {
        moments: [
          {
            student_name: 'Your students',
            context: 'At the beginning of each session',
            suggestion: 'Ask "What would you like to work on today?" or "What are your goals for this session?"',
            reason: 'This helps focus the session and ensures you address student needs'
          }
        ]
      },
      'closing_summary' => {
        moments: [
          {
            student_name: 'Your students',
            context: 'At the end of each session',
            suggestion: 'Say "Today we covered X, Y, and Z. Next time we will work on..."',
            reason: 'This helps students retain what they learned and sets expectations for future sessions'
          }
        ]
      },
      'negative_phrasing' => {
        moments: [
          {
            student_name: 'Your students',
            context: 'When correcting or providing feedback',
            suggestion: 'Instead of "That is wrong", try "Let us try a different approach" or "That is close, but let us think about..."',
            reason: 'Positive language maintains student confidence and encourages learning'
          }
        ]
      },
      'lateness' => {
        moments: [
          {
            student_name: 'Your students',
            context: 'Session start time',
            suggestion: 'Set a reminder 5 minutes before each session and aim to join 2-3 minutes early',
            reason: 'Starting on time shows respect for student time and sets a professional tone'
          }
        ]
      },
      'shortfall' => {
        moments: [
          {
            student_name: 'Your students',
            context: 'Session end time',
            suggestion: 'Plan your session content to fill the full duration, or use extra time for review',
            reason: 'Completing full sessions ensures students receive the full value they expect'
          }
        ]
      },
      'tech_issue' => {
        moments: [
          {
            student_name: 'Your students',
            context: 'Before sessions start',
            suggestion: 'Test your internet connection, camera, and microphone before each session',
            reason: 'Preventing tech issues ensures smooth sessions and better student experience'
          }
        ]
      }
    }

    {
      actionable_item_type: @actionable_item_type,
      moments: fallback_messages[@actionable_item_type]&.dig(:moments) || fallback_messages['encouragement'][:moments],
      cached: false,
      fallback: true
    }
  end

  def cache_feedback(feedback)
    Rails.cache.write(cache_key, feedback, expires_in: CACHE_EXPIRY)
  end

  def increment_rate_limit
    current_count = Rails.cache.read(rate_limit_key) || 0
    Rails.cache.write(rate_limit_key, current_count + 1, expires_in: 1.day)
  end

  def cache_key
    "ai_feedback:tutor:#{@tutor.id}:#{@actionable_item_type}"
  end

  def rate_limit_key
    "ai_feedback_rate_limit:tutor:#{@tutor.id}"
  end
end

