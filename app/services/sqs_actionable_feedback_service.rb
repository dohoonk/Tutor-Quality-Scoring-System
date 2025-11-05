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

    # Check if all sessions were perfect (no deductions)
    if deductions[:total_sessions_with_deductions] == 0
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
    lateness_total_minutes = 0
    shortfall_total_minutes = 0
    
    sqs_scores.each do |score|
      components = score.components || {}
      
      # Check for lateness penalty (can be stored as lateness_penalty or lateness_minutes)
      if components['lateness_penalty']&.positive? || components[:lateness_penalty]&.positive?
        lateness_count += 1
        lateness_minutes = components['lateness_minutes'] || components[:lateness_minutes] || 0
        lateness_total_minutes += lateness_minutes.to_f
      end
      
      # Check for shortfall/duration penalty (SessionScoringJob uses 'duration_penalty', SessionQualityScoreService uses 'shortfall_penalty')
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
      
      # Check for tech issue penalty
      if components['tech_penalty']&.positive? || components[:tech_penalty]&.positive?
        tech_issue_count += 1
      end
    end

    total_with_deductions = lateness_count + shortfall_count + tech_issue_count
    
    # Determine most common issue
    most_common = if lateness_count >= shortfall_count && lateness_count >= tech_issue_count
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
      lateness_avg_minutes: lateness_count > 0 ? (lateness_total_minutes / lateness_count).round(1) : 0,
      shortfall_avg_minutes: shortfall_count > 0 ? (shortfall_total_minutes / shortfall_count).round(1) : 0,
      total_sessions_with_deductions: total_with_deductions,
      most_common_issue: most_common
    }
  end

  def generate_actionable_items(deductions)
    items = []

    # Lateness feedback
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

    # Shortfall feedback
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

    # Tech issue feedback
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

