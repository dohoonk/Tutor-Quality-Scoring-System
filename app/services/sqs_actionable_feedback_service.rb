class SqsActionableFeedbackService
  def initialize(tutor)
    @tutor = tutor
  end

  def generate_feedback
    # Get last 10 SQS scores with components
    sqs_scores = Score.where(tutor: @tutor, score_type: 'sqs')
                      .includes(:session)
                      .order(computed_at: :desc)
                      .limit(10)

    return { perfect: true, message: nil, items: [] } if sqs_scores.empty?

    # Analyze deductions
    deductions = analyze_deductions(sqs_scores)

    # Check if all sessions were perfect (score = 100 and no deductions)
    perfect_sessions = sqs_scores.count do |score|
      score.value.to_f >= 100 && 
      (score.components || {}).values.all? { |v| v.to_f == 0 || v.nil? }
    end
    
    if perfect_sessions == sqs_scores.count && deductions[:total_sessions_with_deductions] == 0
      return {
        perfect: true,
        message: "You're doing a fantastic job! All your last 10 sessions had perfect scores with no issues.",
        items: []
      }
    end

    # Generate actionable items based on deductions
    actionable_items = generate_actionable_items(deductions)

    {
      perfect: false,
      message: nil,
      items: actionable_items,
      summary: {
        total_sessions: sqs_scores.count,
        sessions_with_deductions: deductions[:total_sessions_with_deductions],
        most_common_issue: deductions[:most_common_issue]
      }
    }
  end

  private

  def analyze_deductions(sqs_scores)
    lateness_count = 0
    shortfall_count = 0
    tech_issue_count = 0
    confusion_count = 0
    word_share_count = 0
    goal_setting_count = 0
    encouragement_count = 0
    closing_summary_count = 0
    negative_phrasing_count = 0
    lateness_total_minutes = 0
    shortfall_total_minutes = 0
    
    sqs_scores.each do |score|
      components = score.components || {}
      
      # Operational penalties
      if components['lateness_penalty']&.positive? || components[:lateness_penalty]&.positive?
        lateness_count += 1
        lateness_minutes = components['lateness_minutes'] || components[:lateness_minutes] || 0
        lateness_total_minutes += lateness_minutes.to_f
      end
      
      duration_penalty = components['duration_penalty'] || components[:duration_penalty]
      shortfall_penalty = components['shortfall_penalty'] || components[:shortfall_penalty]
      
      if (duration_penalty&.positive? || shortfall_penalty&.positive?)
        shortfall_count += 1
        shortfall_minutes = components['duration_shortfall_minutes'] || 
                           components[:duration_shortfall_minutes] ||
                           components['shortfall_minutes'] ||
                           components[:shortfall_minutes] || 0
        shortfall_total_minutes += shortfall_minutes.to_f
      end
      
      if components['tech_penalty']&.positive? || components[:tech_penalty]&.positive?
        tech_issue_count += 1
      end
      
      # Transcript-based penalties (new in SQS)
      if components['confusion_phrases']&.positive? || components[:confusion_phrases]&.positive?
        confusion_count += 1
      end
      
      if components['word_share_imbalance']&.positive? || components[:word_share_imbalance]&.positive?
        word_share_count += 1
      end
      
      if components['missing_goal_setting']&.positive? || components[:missing_goal_setting]&.positive?
        goal_setting_count += 1
      end
      
      if components['missing_encouragement']&.positive? || components[:missing_encouragement]&.positive?
        encouragement_count += 1
      end
      
      if components['missing_closing_summary']&.positive? || components[:missing_closing_summary]&.positive?
        closing_summary_count += 1
      end
      
      if components['negative_phrasing']&.positive? || components[:negative_phrasing]&.positive?
        negative_phrasing_count += 1
      end
    end

    total_with_deductions = lateness_count + shortfall_count + tech_issue_count + 
                           confusion_count + word_share_count + goal_setting_count + 
                           encouragement_count + closing_summary_count + negative_phrasing_count
    
    # Determine most common issue (prioritize transcript issues for better feedback)
    most_common = if confusion_count >= [word_share_count, goal_setting_count, encouragement_count, closing_summary_count, negative_phrasing_count, lateness_count, shortfall_count, tech_issue_count].max
                   'confusion'
                 elsif word_share_count >= [goal_setting_count, encouragement_count, closing_summary_count, negative_phrasing_count, lateness_count, shortfall_count, tech_issue_count].max
                   'word_share'
                 elsif goal_setting_count >= [encouragement_count, closing_summary_count, negative_phrasing_count, lateness_count, shortfall_count, tech_issue_count].max
                   'goal_setting'
                 elsif closing_summary_count >= [encouragement_count, negative_phrasing_count, lateness_count, shortfall_count, tech_issue_count].max
                   'closing_summary'
                 elsif encouragement_count >= [negative_phrasing_count, lateness_count, shortfall_count, tech_issue_count].max
                   'encouragement'
                 elsif lateness_count >= [shortfall_count, tech_issue_count].max
                   'lateness'
                 elsif shortfall_count >= tech_issue_count
                   'shortfall'
                 else
                   'tech_issue'
                 end

    {
      lateness_count: lateness_count,
      shortfall_count: shortfall_count,
      tech_issue_count: tech_issue_count,
      confusion_count: confusion_count,
      word_share_count: word_share_count,
      goal_setting_count: goal_setting_count,
      encouragement_count: encouragement_count,
      closing_summary_count: closing_summary_count,
      negative_phrasing_count: negative_phrasing_count,
      lateness_avg_minutes: lateness_count > 0 ? (lateness_total_minutes / lateness_count).round(1) : 0,
      shortfall_avg_minutes: shortfall_count > 0 ? (shortfall_total_minutes / shortfall_count).round(1) : 0,
      total_sessions_with_deductions: total_with_deductions,
      most_common_issue: most_common
    }
  end

  def generate_actionable_items(deductions)
    items = []

    # Transcript-based feedback (prioritized for better learning)
    if deductions[:confusion_count] > 0
      items << {
        type: 'confusion',
        priority: deductions[:confusion_count] >= 5 ? 'high' : 'medium',
        title: 'Address Student Confusion',
        description: "Students expressed confusion in #{deductions[:confusion_count]} out of 10 recent sessions.",
        action: "When you notice confusion phrases like 'I don't understand', pause and clarify. Ask 'What part would you like me to explain differently?'",
        icon: '🤔'
      }
    end

    if deductions[:word_share_count] > 0
      items << {
        type: 'word_share',
        priority: deductions[:word_share_count] >= 5 ? 'high' : 'medium',
        title: 'Balance Conversation',
        description: "You spoke more than 75% of the time in #{deductions[:word_share_count]} out of 10 recent sessions.",
        action: "Aim for 40-60% student speaking time. Ask open-ended questions, give students time to think, and let them explain their reasoning.",
        icon: '💬'
      }
    end

    if deductions[:goal_setting_count] > 0
      items << {
        type: 'goal_setting',
        priority: deductions[:goal_setting_count] >= 5 ? 'high' : 'medium',
        title: 'Set Goals Early',
        description: "You didn't ask about goals in the first few minutes of #{deductions[:goal_setting_count]} out of 10 recent sessions.",
        action: "Start each session by asking 'What would you like to work on today?' or 'What are your goals for this session?' This helps focus the session.",
        icon: '🎯'
      }
    end

    if deductions[:closing_summary_count] > 0
      items << {
        type: 'closing_summary',
        priority: deductions[:closing_summary_count] >= 5 ? 'high' : 'medium',
        title: 'Summarize at the End',
        description: "You didn't provide a summary or next steps in #{deductions[:closing_summary_count]} out of 10 recent sessions.",
        action: "End each session with a brief recap: 'Today we covered X, Y, and Z. Next time we'll work on...' This helps students retain what they learned.",
        icon: '📝'
      }
    end

    if deductions[:encouragement_count] > 0
      items << {
        type: 'encouragement',
        priority: 'medium',
        title: 'Use More Encouragement',
        description: "You didn't use encouragement phrases in #{deductions[:encouragement_count]} out of 10 recent sessions.",
        action: "Use phrases like 'Great question!', 'Well done!', or 'You're doing well!' throughout the session to build student confidence.",
        icon: '👍'
      }
    end

    if deductions[:negative_phrasing_count] > 0
      items << {
        type: 'negative_phrasing',
        priority: 'medium',
        title: 'Use Positive Language',
        description: "Negative phrasing was detected in #{deductions[:negative_phrasing_count]} out of 10 recent sessions.",
        action: "Instead of 'That's wrong', try 'Let's try a different approach' or 'That's close, but let's think about...' Focus on constructive feedback.",
        icon: '✨'
      }
    end

    # Operational feedback
    if deductions[:lateness_count] > 0
      avg_lateness = deductions[:lateness_avg_minutes]
      items << {
        type: 'lateness',
        priority: deductions[:lateness_count] >= 5 ? 'high' : 'medium',
        title: 'Start Sessions on Time',
        description: "You were late to #{deductions[:lateness_count]} out of 10 recent sessions, averaging #{avg_lateness} minutes late.",
        action: "Try setting a reminder 5 minutes before each session. Aim to join 2-3 minutes early to ensure you're ready when the student arrives.",
        icon: '⏰'
      }
    end

    if deductions[:shortfall_count] > 0
      avg_shortfall = deductions[:shortfall_avg_minutes]
      items << {
        type: 'shortfall',
        priority: deductions[:shortfall_count] >= 5 ? 'high' : 'medium',
        title: 'Complete Full Session Duration',
        description: "You ended #{deductions[:shortfall_count]} sessions early, averaging #{avg_shortfall} minutes short.",
        action: "Plan your session content to fill the full duration. If you finish early, use the extra time for review, practice problems, or goal setting.",
        icon: '⏱️'
      }
    end

    if deductions[:tech_issue_count] > 0
      items << {
        type: 'tech_issue',
        priority: deductions[:tech_issue_count] >= 3 ? 'high' : 'medium',
        title: 'Resolve Technical Issues',
        description: "You experienced technical issues in #{deductions[:tech_issue_count]} out of 10 recent sessions.",
        action: "Test your internet connection, camera, and microphone before each session. Have a backup plan ready if issues occur.",
        icon: '🔧'
      }
    end

    # Sort by priority (high first), then by type
    items.sort_by { |item| [-priority_value(item[:priority]), item[:type]] }
  end

  def priority_value(priority)
    case priority
    when 'high' then 3
    when 'medium' then 2
    when 'low' then 1
    else 0
    end
  end
end

